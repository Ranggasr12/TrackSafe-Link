/**
 * Local development only — JANGAN dipakai di Vercel.
 * Vercel memakai api/index.js (module.exports = app).
 */

require('dotenv').config();

const app = require('./app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`[local] TrackSafe backend http://localhost:${PORT}`);
  console.log(`[local] GET  http://localhost:${PORT}/api/status`);
  console.log(`[local] POST http://localhost:${PORT}/api/sensor`);
});
