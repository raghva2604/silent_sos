const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const fs = require('fs');

const app = express();
app.use(bodyParser.json());

// Protect the endpoint with a simple API key (set FCM_API_KEY env var)
function requireApiKey(req, res, next) {
  const apiKey = process.env.FCM_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Server not configured (FCM_API_KEY missing)' });
  const provided = req.header('x-api-key') || req.body.apiKey || req.query.apiKey;
  if (!provided || provided !== apiKey) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

// Initialize firebase-admin using GOOGLE_APPLICATION_CREDENTIALS or a local file
try {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
    admin.initializeApp();
  } else if (fs.existsSync('./serviceAccountKey.json')) {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    console.warn('No service account found. Set GOOGLE_APPLICATION_CREDENTIALS or put serviceAccountKey.json in this folder.');
  }
} catch (e) {
  console.error('Failed to initialize firebase-admin:', e);
}

app.post('/send', requireApiKey, async (req, res) => {
  const { token, topic, title, body, data } = req.body;
  if (!token && !topic) return res.status(400).json({ error: 'token or topic required' });

  const message = {
    notification: { title: title || 'Silent SOS', body: body || '' },
    android: { priority: 'high' },
    apns: { headers: { 'apns-priority': '10' } },
    data: data || {},
  };

  try {
    let result;
    if (token) {
      result = await admin.messaging().send({ ...message, token });
    } else {
      result = await admin.messaging().send({ ...message, topic });
    }
    res.json({ success: true, result });
  } catch (e) {
    console.error('FCM send error:', e);
    res.status(500).json({ error: e.toString() });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`FCM server listening on ${PORT}`));
