require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { connectDb } = require('./db');
const locationRoutes = require('./routes/location');
const aiRoutes = require('./routes/ai');
const { initSocketServer } = require('./websocket/socket');

const app = express();
const PORT = process.env.PORT || 3000;
const uploadDir = path.join(__dirname, 'uploads');

function getLocalNetworkIp() {
  const interfaces = os.networkInterfaces();
  const candidates = [];

  for (const addresses of Object.values(interfaces)) {
    for (const address of addresses || []) {
      if (!address.internal && address.family === 'IPv4') {
        candidates.push(address.address);
      }
    }
  }

  const preferredOrder = (ip) => {
    if (ip.startsWith('10.')) return 0;
    if (ip.startsWith('192.168.')) return 1;
    if (ip.startsWith('172.')) return 2;
    return 3;
  };

  candidates.sort((a, b) => preferredOrder(a) - preferredOrder(b));

  return candidates[0] || '127.0.0.1';
}

const serverHost = process.env.SERVER_HOST || getLocalNetworkIp();
const serverBaseUrl = process.env.SERVER_BASE_URL || `http://${serverHost}:${PORT}`;
const listenHost = process.env.LISTEN_HOST || '0.0.0.0';

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(uploadDir));

app.get('/', (req, res) => {
  res.send('Silent SOS Backend Running');
});

app.post('/generate-upload-url', (req, res) => {
  const { sessionId, filename } = req.body || {};
  const safeName = (filename || `${Date.now()}.mp4`).replace(/[^a-zA-Z0-9._-]/g, '_');
  const videoKey = `${sessionId || Date.now()}/${safeName}`;
  const uploadUrl = `${serverBaseUrl}/uploads/${safeName}`;
  const publicUrl = `${serverBaseUrl}/uploads/${safeName}`;

  res.json({ uploadUrl, videoKey, publicUrl });
});

app.post('/generate-download-url', (req, res) => {
  const { videoKey } = req.body || {};
  const fileName = (videoKey || '').split('/').pop() || 'video.mp4';
  const downloadUrl = `${serverBaseUrl}/uploads/${fileName}`;
  res.json({ downloadUrl, expiresIn: 86400, expiresAt: new Date(Date.now() + 86400000).toISOString() });
});

app.put('/uploads/:fileName', (req, res) => {
  const { fileName } = req.params;
  const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
  const filePath = path.join(uploadDir, safeName);
  const writeStream = fs.createWriteStream(filePath);

  req.pipe(writeStream);

  writeStream.on('finish', () => {
    res.status(201).send('uploaded');
  });

  writeStream.on('error', (error) => {
    res.status(500).json({ error: error.message });
  });
});

app.post(['/sos-send-sos', '/prod/sos-send-sos', '/sos'], (req, res) => {
  const payload = req.body || {};
  console.log(`[SOS] ${req.method} ${req.path}`);
  console.log(JSON.stringify(payload));

  res.status(200).json({
    success: true,
    message: 'SOS alert received',
    receivedAt: new Date().toISOString(),
    sessionId: payload.sessionId || null,
    recipientCount: Array.isArray(payload.emails)
      ? payload.emails.length
      : Array.isArray(payload.contacts)
        ? payload.contacts.length
        : 0,
  });
});

app.use('/', locationRoutes);
app.use('/ai', aiRoutes);

const server = http.createServer(app);
initSocketServer(server);

server.listen(PORT, listenHost, async () => {
  console.log('Server Started');
  console.log(`Port ${PORT}`);
  console.log(`Host ${listenHost}`);
  console.log(`Base URL ${serverBaseUrl}`);
  console.log('POST /update-live-location ready');
  await connectDb();
});
