/**
 * Local development only — JANGAN dipakai di Vercel.
 * Vercel memakai api/index.js (module.exports = app).
 *
 * Development Only: URL localhost di bawah hanya untuk log lokal.
 */

require('dotenv').config();

const app = require('./app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  // Development Only
  console.log(`[local] TrackSafe backend http://localhost:${PORT}`);
  console.log(`[local] GET  http://localhost:${PORT}/api/status`);
  console.log(`[local] POST http://localhost:${PORT}/api/sensor`);
  console.log(`[local] GET  http://localhost:${PORT}/api/device/:deviceId`);
  console.log(`[local] GET  http://localhost:${PORT}/api/devices`);
  console.log(`[local] POST http://localhost:${PORT}/api/device/heartbeat`);
});
