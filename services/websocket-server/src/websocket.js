// WebSocket utility helpers
module.exports = { broadcast: (wss, data) => {
  wss.clients.forEach(client => {
    if (client.readyState === 1) client.send(JSON.stringify(data));
  });
}};
