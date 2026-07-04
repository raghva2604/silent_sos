const WebSocket = require('ws');

let wss = null;

function initSocketServer(server) {
  wss = new WebSocket.Server({ server });

  wss.on('connection', (ws) => {
    console.log('WebSocket client connected');

    ws.on('message', (message) => {
      try {
        const payload = JSON.parse(message.toString());
        console.log('WS message received:', payload);
        ws.send(JSON.stringify({ ok: true, received: payload }));
      } catch (error) {
        ws.send(JSON.stringify({ ok: false, error: error.message }));
      }
    });

    ws.on('close', () => {
      console.log('WebSocket client disconnected');
    });
  });
}

function broadcastLocation(data) {
  if (!wss) return;
  const payload = typeof data === 'string' ? data : JSON.stringify(data);

  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  });
}

module.exports = {
  initSocketServer,
  broadcastLocation,
};
