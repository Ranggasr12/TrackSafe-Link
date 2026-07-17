/**
 * 404 handler — route tidak ditemukan.
 */
function notFoundHandler(req, res, next) {
  res.status(404).json({
    success: false,
    error: 'Route not found',
    path: req.originalUrl,
    method: req.method,
  });
}

module.exports = { notFoundHandler };
