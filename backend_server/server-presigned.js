// server.js - Presigned S3 + Socket.io + MongoDB
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { MongoClient, ObjectId } = require('mongodb');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: '*' } });

// Env config - set in .env
const {
  AWS_REGION = 'us-east-1',
  AWS_ACCESS_KEY_ID,
  AWS_SECRET_ACCESS_KEY,
  S3_BUCKET,
  MONGO_URI = 'mongodb://localhost:27017/silent_sos',
  PORT = 4000
} = process.env;

if (!AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY || !S3_BUCKET) {
  console.warn('⚠️  Missing AWS env vars. Set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_BUCKET');
}

// Initialize S3 client
const s3 = new S3Client({
  region: AWS_REGION,
  credentials: { accessKeyId: AWS_ACCESS_KEY_ID, secretAccessKey: AWS_SECRET_ACCESS_KEY }
});

// MongoDB
const mongoClient = new MongoClient(MONGO_URI, { useUnifiedTopology: true });
let db;
mongoClient.connect().then(() => {
  db = mongoClient.db();
  console.log('✓ Connected to MongoDB');
}).catch(err => {
  console.error('✗ Mongo connect failed', err);
  process.exit(1);
});

// ============ Routes ============

// Health check
app.get('/health', (req, res) => res.json({ ok: true }));

// AI health probe (client calls this to check if AI service is available)
app.get('/ai/health', (req, res) => {
  res.json({ ok: true, model: 'ai-stub-v1' });
});

// ========== PRESIGN endpoint ==========
// POST /api/presign
// Client sends: { files: [{ fileName, contentType, keyPrefix }, ...] }
// Server responds: { ok: true, presigned: [{ fileName, key, putUrl, objectUrl }, ...] }
app.post('/api/presign', async (req, res) => {
  try {
    const files = req.body.files;
    if (!Array.isArray(files) || files.length === 0) {
      return res.status(400).json({ error: 'files array required' });
    }

    const results = [];
    for (const f of files) {
      const prefix = f.keyPrefix || 'sos';
      // Sanitize filename to prevent path traversal
      const safeName = `${Date.now()}_${f.fileName.replace(/[^a-zA-Z0-9_.-]/g, '_')}`;
      const key = `${prefix}/${safeName}`;
      
      const params = {
        Bucket: S3_BUCKET,
        Key: key,
        ContentType: f.contentType || 'application/octet-stream',
        ACL: 'public-read' // Ensure public access; in production use private + presigned GET
      };
      
      const putCommand = new PutObjectCommand(params);
      const putUrl = await getSignedUrl(s3, putCommand, { expiresIn: 60 * 5 }); // 5 min expiry
      const objectUrl = `https://${S3_BUCKET}.s3.${AWS_REGION}.amazonaws.com/${key}`;
      
      results.push({
        fileName: f.fileName,
        key,
        putUrl,
        objectUrl
      });
    }

    res.json({ ok: true, presigned: results });
  } catch (err) {
    console.error('Presign error:', err);
    res.status(500).json({ error: 'server error' });
  }
});

// ========== Final SOS endpoint ==========
// POST /api/sos
// Client sends: { userId, timestamp, lat?, lon?, source, media: { frontUrl, backUrl, audioUrl } }
// Server saves to DB and emits socket.io event to operators
app.post('/api/sos', async (req, res) => {
  try {
    const payload = req.body;
    if (!payload || !payload.userId) {
      return res.status(400).json({ error: 'payload.userId required' });
    }

    const sosDoc = {
      userId: payload.userId,
      source: payload.source || 'manual',
      timestamp: payload.timestamp || Date.now(),
      location: payload.lat && payload.lon ? { lat: payload.lat, lon: payload.lon } : null,
      media: payload.media || {},
      resolved: false,
      createdAt: new Date()
    };

    const r = await db.collection('sos').insertOne(sosDoc);
    sosDoc._id = r.insertedId;

    // Emit to connected operators
    io.to('ops').emit('new_sos', sosDoc);
    console.log(`✓ New SOS: ${sosDoc._id} from ${sosDoc.userId}`);

    res.json({ ok: true, id: r.insertedId, sos: sosDoc });
  } catch (err) {
    console.error('SOS error:', err);
    res.status(500).json({ error: 'server error' });
  }
});

// ========== Operator acknowledgment ==========
// POST /api/sos/:id/ack
app.post('/api/sos/:id/ack', async (req, res) => {
  try {
    const id = req.params.id;
    const result = await db.collection('sos').updateOne(
      { _id: new ObjectId(id) },
      { $set: { resolved: true, acknowledgedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'SOS not found' });
    }

    io.to('ops').emit('sos_ack', { id });
    console.log(`✓ SOS acknowledged: ${id}`);

    res.json({ ok: true });
  } catch (err) {
    console.error('ACK error:', err);
    res.status(500).json({ error: 'server error' });
  }
});

// ========== Operator dashboard data ==========
// GET /api/sos - retrieve recent SOS records (for dashboard on page load)
app.get('/api/sos', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || '50');
    const records = await db.collection('sos')
      .find({})
      .sort({ createdAt: -1 })
      .limit(limit)
      .toArray();

    res.json({ ok: true, data: records });
  } catch (err) {
    console.error('Get SOS error:', err);
    res.status(500).json({ error: 'server error' });
  }
});

// ========== Socket.io for real-time operator dashboard ==========
io.on('connection', (socket) => {
  console.log(`📡 Socket connected: ${socket.id}`);

  socket.on('join_ops', () => {
    socket.join('ops');
    console.log(`👤 Operator joined: ${socket.id}`);
  });

  socket.on('disconnect', () => {
    console.log(`📡 Socket disconnected: ${socket.id}`);
  });
});

// ========== Start server ==========
server.listen(PORT, () => {
  console.log(`\n🚀 Silent SOS Server running on port ${PORT}`);
  console.log(`📍 Endpoints:`);
  console.log(`   GET  /health`);
  console.log(`   GET  /ai/health`);
  console.log(`   POST /api/presign`);
  console.log(`   POST /api/sos`);
  console.log(`   POST /api/sos/:id/ack`);
  console.log(`   GET  /api/sos`);
  console.log(`\n`);
});
