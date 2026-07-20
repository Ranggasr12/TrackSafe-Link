/**
 * Express application factory (tanpa app.listen).
 * Digunakan oleh Railway (server.js) dan legacy Vercel (api/index.js).
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');

const apiRoutes = require('./routes');
const statusController = require('./controllers/status.controller');
const { notFoundHandler } = require('./middleware/notFound');
const { errorHandler } = require('./middleware/errorHandler');
const { initFirebase } = require('./config/firebase');
const logger = require('./config/logger');

const app = express();

app.disable('x-powered-by');

/**
 * CORS — production memakai ALLOWED_ORIGIN / FRONTEND_URL jika di-set.
 * Jika kosong: tetap open CORS (kompatibel ESP32 / client lama).
 * Tidak mengubah shape response API.
 */
function buildCorsOptions() {
  const raw = process.env.ALLOWED_ORIGIN || process.env.FRONTEND_URL || '';
  const origins = String(raw)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (origins.length === 0) {
    return undefined; // cors() default reflect/all
  }
  if (origins.length === 1) {
    return { origin: origins[0] };
  }
  return { origin: origins };
}

const corsOptions = buildCorsOptions();
app.use(corsOptions ? cors(corsOptions) : cors());

app.use(express.json({ limit: '256kb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging — Development Only (bukan production spam).
if (!logger.isProduction()) {
  app.use((req, _res, next) => {
    logger.debug(`[req] ${req.method} ${req.url} (originalUrl=${req.originalUrl})`);
    next();
  });
}

/**
 * Beberapa runtime Vercel memotong prefix /api saat function di api/index.js.
 * Dual-mount mencegah Routing error (404) untuk /status vs /api/status.
 */
app.use((req, _res, next) => {
  // Jika path datang tanpa leading slash, normalisasi
  if (req.url && !req.url.startsWith('/')) {
    req.url = `/${req.url}`;
  }
  next();
});

// Eager init Firebase saat cold start (jangan crash process jika gagal)
try {
  initFirebase();
} catch (error) {
  logger.error('[app] Firebase warm-init failed:', error.message);
}

// Root info
app.get('/', (_req, res) => {
  res.status(200).json({
    success: true,
    name: 'TrackSafe Link Backend',
    mode: process.env.RAILWAY_ENVIRONMENT ? 'railway-persistent' : 'express',
    endpoints: {
      status: 'GET /api/status',
      sensor: 'POST /api/sensor',
      device: 'GET /api/device/:deviceId',
      devices: 'GET /api/devices',
      heartbeat: 'POST /api/device/heartbeat',
      history: 'GET /api/history',
      debugDevice: 'GET /api/debug/device/:deviceId',
      debugHistory: 'GET /api/debug/history',
    },
  });
});

// Mount di /api (path asli) dan root (jika prefix di-strip oleh platform)
app.use('/api', apiRoutes);
app.use(apiRoutes);

// Health check — Railway + monitoring
app.get('/health', statusController.getHealth);
app.get('/api/health', statusController.getHealth);

// Legacy status alias
app.get('/api/status', statusController.getStatus);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
