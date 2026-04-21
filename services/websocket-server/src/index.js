const { WebSocketServer } = require("ws");
const redisClient         = require("./redis_client");
const { broadcast }       = require("./websocket");

const PORT            = parseInt(process.env.PORT || "8080");
const PUSH_INTERVAL   = parseInt(process.env.PUSH_INTERVAL_MS || "1000");

const EVENT_TYPES = ["page_view", "click", "purchase", "signup", "logout"];

const wss = new WebSocketServer({ port: PORT });
console.log(`WebSocket server listening on port ${PORT}`);

wss.on("connection", (ws, req) => {
  console.log("Client connected:", req.socket.remoteAddress);

  sendCurrentCounts(ws);

  ws.on("close", () => console.log("Client disconnected"));
  ws.on("error", (err) => console.error("WebSocket client error:", err));
});

async function sendCurrentCounts(target) {
  try {
    const counts = {};
    for (const eventType of EVENT_TYPES) {
      const val = await redisClient.get(`event_count:${eventType}`);
      counts[eventType] = parseInt(val || "0");
    }

    const payload = { type: "event_counts", data: counts, timestamp: new Date().toISOString() };

    if (target) {
      if (target.readyState === 1) target.send(JSON.stringify(payload));
    } else {
      broadcast(wss, payload);
    }
  } catch (err) {
    console.error("Failed to read from Redis:", err);
  }
}

setInterval(() => sendCurrentCounts(null), PUSH_INTERVAL);

async function shutdown(signal) {
  console.log(`${signal} received, shutting down...`);
  wss.close(() => console.log("WebSocket server closed"));
  await redisClient.quit();
  process.exit(0);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT",  () => shutdown("SIGINT"));