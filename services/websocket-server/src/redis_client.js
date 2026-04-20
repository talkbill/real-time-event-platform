const { createClient } = require("redis");

const client = createClient({
  socket: { host: process.env.REDIS_HOST || "redis-master.redis", port: 6379 },
});
client.connect().catch(console.error);
module.exports = client;
