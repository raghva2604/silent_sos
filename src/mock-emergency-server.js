// Simple mock server to emulate the emergency webhook for local testing
// Run: node src/mock-emergency-server.js

const http = require('http');
const { StringDecoder } = require('string_decoder');

const PORT = process.env.MOCK_EMERGENCY_PORT || 3001;

const server = http.createServer((req, res) => {
  const url = req.url;
  const method = req.method.toUpperCase();
  const headers = req.headers;

  console.log(`[mock] ${method} ${url}`);

  if (method === 'POST' && url === '/webhook/emergency-ai') {
    const decoder = new StringDecoder('utf8');
    let buffer = '';

    req.on('data', (chunk) => {
      buffer += decoder.write(chunk);
    });

    req.on('end', () => {
      buffer += decoder.end();

      let parsed = buffer;
      try {
        parsed = JSON.parse(buffer);
      } catch (e) {
        // not JSON, keep raw
      }

      // Basic auth/key check (optional)
      const apiKey = headers['x-api-key'] || headers['x-api-key'.toLowerCase()];
      if (!apiKey) {
        // still return 200 for local testing but include warning
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true, warning: 'no-api-key-provided', received: parsed }));
        console.log('[mock] responded 200 (no api key)');
        return;
      }

      // Echo back the payload
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, received: parsed }));
      console.log('[mock] responded 200');
    });

    return;
  }

  // Default 404 for other paths
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ code: 404, message: 'Not Found - mock server' }));
});

server.listen(PORT, () => {
  console.log(`[mock] Emergency mock server listening on http://localhost:${PORT}`);
});
