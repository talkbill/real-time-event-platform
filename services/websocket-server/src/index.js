const { WebSocketServer } = require("ws");
const { createClient }    = require("redis");

const PORT = process.env.PORT || 8080;
const wss  = new WebSocketServer({ port: PORT });

const redisClient = createClient({
  socket: { host: process.env.REDIS_HOST || "redis-master.redis", port: 6379 },
});
redisClient.connect().catch(console.error);

wss.on("connection", (ws) => {
  console.log("Client connected");
  ws.on("message", (msg) => console.log("Received:", msg.toString()));
  ws.on("close",   ()    => console.log("Client disconnected"));
});

console.log(`WebSocket server listening on port ${PORT}`);
