// server.js
require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const sqlite3 = require('sqlite3').verbose();
const nodemailer = require('nodemailer');
const util = require('util');
const crypto = require('crypto');

const app = express();
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// --- Config
const UPLOAD_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const DB_PATH = path.join(__dirname, 'db.sqlite');
const MIGRATION_SQL = fs.readFileSync(path.join(__dirname, 'migrations.sql'), 'utf8');

// --- DB init
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error('Failed to open DB', err);
    process.exit(1);
  }
});
db.exec(MIGRATION_SQL, (err) => {
  if (err) console.error('Migration error', err);
  else console.log('Migrations applied.');
});

// Ensure device_token column exists (add if missing)
db.serialize(() => {
  db.all("PRAGMA table_info('sos_events')", (err, rows) => {
    if (err) {
      console.warn('Could not query table info for sos_events', err);
      return;
    }
    const hasDeviceToken = rows && rows.some(r => r.name === 'device_token');
    if (!hasDeviceToken) {
      console.log('Adding device_token column to sos_events');
      db.run("ALTER TABLE sos_events ADD COLUMN device_token TEXT", (alterErr) => {
        if (alterErr) console.warn('Failed to add device_token column', alterErr);
        else console.log('device_token column added');
      });
    }
  });
});

// Optional FCM: initialize firebase-admin if a service account JSON is present
let fcmAdmin = null;
try {
  const admin = require('firebase-admin');
  const saPath = process.env.FIREBASE_SERVICE_ACCOUNT || path.join(__dirname, 'firebase-service-account.json');
  if (fs.existsSync(saPath)) {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    fcmAdmin = admin;
    console.log('Firebase admin initialized for FCM');
  } else {
    console.log('Firebase service account not found; FCM disabled. Put firebase-service-account.json in backend_server/ or set FIREBASE_SERVICE_ACCOUNT env var.');
  }
} catch (e) {
  console.log('firebase-admin not configured or not installed:', e.message);
}

async function pushEventResolved(deviceToken, eventId) {
  if (!fcmAdmin) return;
  if (!deviceToken) return;
  const message = {
    token: deviceToken,
    notification: {
      title: 'SOS resolved',
      body: `Event ${eventId} marked SAFE by contact`
    },
    data: { eventId: String(eventId), action: 'resolved' }
  };
  try {
    const resp = await fcmAdmin.messaging().send(message);
    console.log('FCM sent', resp);
  } catch (e) {
    console.error('FCM error', e);
  }
}

// promisify db.run / get / all for convenience
const dbRun = util.promisify(db.run.bind(db));
const dbGet = util.promisify(db.get.bind(db));
const dbAll = util.promisify(db.all.bind(db));

// --- Multer for uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const stamp = Date.now();
    const safe = file.originalname.replace(/\s+/g, '_');
    cb(null, `${stamp}_${safe}`);
  }
});
const upload = multer({ storage });

// --- Email transporter factory (Gmail SMTP using app password)
async function createTransporter() {
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_SECURE === 'true', // false for 587
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      }
    });
    try {
      await transporter.verify();
      console.log('SMTP transporter verified');
    } catch (err) {
      console.warn('SMTP verify failed:', err.message);
    }
    return transporter;
  } else {
    // fallback - nodemailer test account
    const testAccount = await nodemailer.createTestAccount();
    return nodemailer.createTransport({
      host: testAccount.smtp.host,
      port: testAccount.smtp.port,
      secure: testAccount.smtp.secure,
      auth: { user: testAccount.user, pass: testAccount.pass }
    });
  }
}

// --- Helpers
function insertEvent({ user_id = '', event_type = 'manual', recipients = [], recording_path = null, extra = {} }) {
  const recipientsJson = JSON.stringify(recipients);
  const extraJson = JSON.stringify(extra);
  const sql = `INSERT INTO sos_events (user_id, event_type, recipients, recording_path, extra) VALUES (?, ?, ?, ?, ?)`;
  return new Promise((resolve, reject) => {
    db.run(sql, [user_id, event_type, recipientsJson, recording_path, extraJson], function (err) {
      if (err) return reject(err);
      db.get('SELECT * FROM sos_events WHERE id = ?', [this.lastID], (err2, row) => {
        if (err2) return reject(err2);
        resolve(row);
      });
    });
  });
}

// helper: create short link record
function genShortToken() {
  // generate a compact base36 token from random bytes
  const buf = crypto.randomBytes(6);
  return BigInt('0x' + buf.toString('hex')).toString(36);
}

function createShortForUpload(db, filePath, filename) {
  return new Promise((resolve, reject) => {
    const tryInsert = () => {
      const short = genShortToken();
      db.run('INSERT INTO recordings(short, path, filename) VALUES (?, ?, ?)', [short, filePath, filename], function(err) {
        if (err) {
          // on unique constraint failure, try again a couple times
          if (err.code === 'SQLITE_CONSTRAINT') return tryInsert();
          return reject(err);
        }
        resolve(short);
      });
    };
    tryInsert();
  });
}

// Convenience to set device_token on an event (if column exists)
function setEventDeviceToken(eventId, token) {
  return new Promise((resolve, reject) => {
    db.run('UPDATE sos_events SET device_token = ? WHERE id = ?', [token, eventId], function (err) {
      if (err) return reject(err);
      resolve(true);
    });
  });
}

function updateEventStatus(id, status) {
  return new Promise((resolve, reject) => {
    db.run(`UPDATE sos_events SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`, [status, id], function (err) {
      if (err) return reject(err);
      db.get(`SELECT * FROM sos_events WHERE id = ?`, [id], (err2, row) => {
        if (err2) return reject(err2);
        resolve(row);
      });
    });
  });
}

// --- Routes

// Health
app.get('/health', (req, res) => res.json({ ok: true }));

// Simple AI chat endpoint - for now, returns a mock response
app.post('/ai/chat', express.json(), (req, res) => {
  try {
    const { input, model } = req.body;
    if (!input) {
      return res.status(400).json({ error: 'Missing input field' });
    }
    // For now, return a simple mock response
    // In production, integrate with Claude API or your chosen LLM
    const reply = `AI (${model || 'default'}): I received your message: "${input}". This is a mock response.`;
    res.json({ reply });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Upload recording (multipart/form-data) -> returns { path, url }
app.post('/upload_recording', upload.single('recording'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'no file' });
    const savedPath = req.file.path; // absolute path
    // Provide a URL that your server can serve
    const host = process.env.PUBLIC_HOST || `${req.protocol}://${req.get('host')}`;
    const url = `${host}/uploads/${path.basename(savedPath)}`;
    const filename = path.basename(savedPath);
    console.log('Uploaded file saved', savedPath);
    // Try to create a short link record
    try {
      const short = await createShortForUpload(db, savedPath, filename);
      const shortUrl = `${host}/r/${short}`;
      return res.json({ ok: true, path: savedPath, url, short, shortUrl });
    } catch (e) {
      console.error('short create err', e);
      return res.json({ ok: true, path: savedPath, url });
    }
  } catch (err) {
    console.error('upload_recording error', err);
    res.status(500).json({ error: 'upload failed' });
  }
});

// Serve uploads statically (optional). In production use signed URLs or protected access.
app.use('/uploads', express.static(UPLOAD_DIR, { index: false }));

// Serve preview page or redirect for short links
app.get('/r/:short', (req, res) => {
  const short = req.params.short;
  db.get('SELECT path, filename FROM recordings WHERE short = ?', [short], (err, row) => {
    if (err || !row) return res.status(404).send('Not found');
    const host = process.env.PUBLIC_HOST || `${req.protocol}://${req.get('host')}`;
    const fileUrl = `${host}/uploads/${row.filename}`;
    res.send(`
      <!doctype html>
      <html>
        <head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
        <body style="font-family: sans-serif; padding: 20px;">
          <h3>Recording preview</h3>
          <p><a href="${fileUrl}" target="_blank">Open raw file</a></p>
          <video controls style="max-width:100%; height:auto;">
            <source src="${fileUrl}" type="video/mp4">
            Your browser does not support the video tag.
          </video>
          <p>If you cannot view, open raw file link.</p>
        </body>
      </html>
    `);
  });
});

// Send SOS: persist event, send email (attachments optional)
app.post('/send-sos', async (req, res) => {
  try {
    const { meta = {}, recipients = [], recordingPath, recordingUrl, deviceToken } = req.body;
    // Persist event
    const event = await insertEvent({
      user_id: meta.user || '',
      event_type: meta.event || 'manual',
      recipients,
      recording_path: recordingPath || recordingUrl || null,
      extra: { meta }
    });
    console.log('Event created', event.id);

    // If a deviceToken provided, save it on the event for push notifications
    if (deviceToken) {
      try { await setEventDeviceToken(event.id, deviceToken); } catch (e) { console.warn('failed to set device token', e); }
    }

    // Prepare email body
    const baseText = `EMERGENCY SOS
Name: ${meta.user || 'Unknown'}
Time: ${meta.time || new Date().toISOString()}
Location: ${meta.lat || ''}, ${meta.lon || ''}
Event: ${meta.event || 'manual'}

This message is generated automatically by the SOS app.
`;

    const transporter = await createTransporter();

    // For each recipient email, send mail (attach file if available locally)
    for (const r of (recipients || [])) {
      if (!r.email) continue;
      const mailOptions = {
        from: process.env.EMAIL_FROM || process.env.SMTP_USER,
        to: r.email,
        subject: `SOS Alert — ${meta.user || 'Unknown'}`,
        text: baseText + (recordingUrl ? `\nRecording: ${recordingUrl}\n` : '')
      };

      // If a local server path provided and file exists, attach
      const attachPath = recordingPath && fs.existsSync(recordingPath) ? recordingPath : null;
      if (attachPath) {
        mailOptions.attachments = [
          {
            filename: path.basename(attachPath),
            path: attachPath
          }
        ];
      }

      try {
        const info = await transporter.sendMail(mailOptions);
        console.log('Email sent to', r.email, 'id:', info.messageId);
        if (nodemailer.getTestMessageUrl && nodemailer.getTestMessageUrl(info)) {
          console.log('Preview URL:', nodemailer.getTestMessageUrl(info));
        }
      } catch (mailErr) {
        console.error('Error sending email to', r.email, mailErr);
      }
    }

    // Respond with created event (re-fetch to include device_token if updated)
    const saved = await dbGet('SELECT * FROM sos_events WHERE id = ?', [event.id]);
    res.json({ ok: true, event: saved });
  } catch (err) {
    console.error('/send-sos error', err);
    res.status(500).json({ error: 'send-sos failed' });
  }
});

// Simple endpoint to mark event resolved (simulate Twilio webhook)
app.post('/sms-webhook', async (req, res) => {
  try {
    const from = req.body.From || req.body.from || '';
    const body = (req.body.Body || req.body.body || '').toString().trim().toLowerCase();
    console.log('sms-webhook', from, body);
    // If message contains 'safe', mark last open event resolved (simple heuristic)
    if (body.includes('safe')) {
      const row = await dbGet(`SELECT * FROM sos_events WHERE status='open' ORDER BY created_at DESC LIMIT 1`);
      if (row) {
        const updated = await updateEventStatus(row.id, 'resolved');
        console.log('Marked event resolved', updated.id);
        // send FCM if device_token present
        try {
          const token = row.device_token || (row.extra && JSON.parse(row.extra || '{}').deviceToken) || null;
          if (token) await pushEventResolved(token, updated.id);
        } catch (e) {
          console.warn('Failed to send FCM on resolve', e);
        }
        return res.json({ ok: true, resolved: updated });
      }
    }
    res.json({ ok: true });
  } catch (err) {
    console.error('sms-webhook error', err);
    res.status(500).json({ error: 'webhook failed' });
  }
});

// Get event by id
app.get('/event/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const row = await dbGet(`SELECT * FROM sos_events WHERE id = ?`, [id]);
    if (!row) return res.status(404).json({ error: 'not found' });
    res.json({ ok: true, event: row });
  } catch (err) {
    console.error('event get error', err);
    res.status(500).json({ error: 'failed' });
  }
});

// Send email via SMTP (POST /send-email)
// Body: { to: ["email1", "email2"], subject, html, attachments?: [{ filename, content }] }
app.post('/send-email', async (req, res) => {
  try {
    const { to, subject, html, attachments } = req.body;
    
    if (!to || !Array.isArray(to) || to.length === 0) {
      return res.status(400).json({ error: 'to array required' });
    }
    if (!subject) {
      return res.status(400).json({ error: 'subject required' });
    }
    if (!html) {
      return res.status(400).json({ error: 'html required' });
    }

    const transporter = await createTransporter();
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'Silent SOS <noreply@silentsos.app>',
      to: to.join(','),
      subject: subject,
      html: html,
      attachments: attachments || []
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`✓ Email sent to ${to.join(', ')}:`, info.messageId || info.response);
    
    res.json({ 
      ok: true, 
      message: 'Email sent successfully', 
      messageId: info.messageId,
      preview: info.preview
    });
  } catch (err) {
    console.error('send-email error:', err);
    res.status(500).json({ error: 'Failed to send email', details: err.message });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Notification server listening on 0.0.0.0:${PORT}`);
});

