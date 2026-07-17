/**
 * Express application factory (tanpa app.listen).
 * Digunakan oleh Vercel Serverless (api/index.js) dan local.js.
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');

const apiRoutes = require('./routes');
const statusController = require('./controllers/status.controller');
const { notFoundHandler } = require('./middleware/notFound');
const { errorHandler } = require('./middleware/errorHandler');
const { initFirebase } = require('./config/firebase');

const app = express();

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '256kb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging — hanya di development / local (bukan business logic).
if (process.env.NODE_ENV !== 'production') {
  app.use((req, _res, next) => {
    console.log(`[req] ${req.method} ${req.url} (originalUrl=${req.originalUrl})`);
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
  console.error('[app] Firebase warm-init failed:', error.message);
}

// Root info
app.get('/', (_req, res) => {
  res.status(200).json({
    success: true,
    name: 'TrackSafe Link Backend',
    mode: 'vercel-serverless',
    endpoints: {
      status: 'GET /api/status',
      sensor: 'POST /api/sensor',
      device: 'GET /api/device/:deviceId',
      history: 'GET /api/history',
      debugDevice: 'GET /api/debug/device/:deviceId',
      debugHistory: 'GET /api/debug/history',
    },
  });
});

// Mount di /api (path asli) dan root (jika prefix di-strip oleh platform)
app.use('/api', apiRoutes);
app.use(apiRoutes);

// Alias health check lama
app.get('/health', statusController.getStatus);
app.get('/api/health', statusController.getStatus);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
