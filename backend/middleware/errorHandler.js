/**
 * Global error handler untuk Express + Vercel.
 */
const logger = require('../config/logger');

function errorHandler(err, req, res, next) {
  const statusCode = err.statusCode || err.status || 500;

  logger.error('[error]', {
    message: err.message,
    statusCode,
    path: req.originalUrl,
    method: req.method,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });

  // Hindari double-send jika headers sudah terkirim
  if (res.headersSent) {
    return next(err);
  }

  res.status(statusCode).json({
    success: false,
    error: err.message || 'Internal Server Error',
    ...(statusCode === 500 && process.env.NODE_ENV === 'development'
      ? { stack: err.stack }
      : {}),
  });
}

module.exports = { errorHandler };
