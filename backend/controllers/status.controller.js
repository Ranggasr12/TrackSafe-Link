const telemetryService = require('../services/telemetry.service');
const { isFirebaseReady } = require('../config/firebase');

/**
 * GET /api/status
 */
async function getStatus(req, res, next) {
  try {
    if (!isFirebaseReady()) {
      console.error('[status] Firebase not ready');
      return res.status(500).json({
        success: false,
        backend: 'online',
        firebase: 'disconnected',
        error: 'Firebase initialization failed',
      });
    }

    await telemetryService.pingFirebase();

    return res.status(200).json({
      success: true,
      backend: 'online',
      firebase: 'connected',
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('[status] error:', error.message);
    error.statusCode = 500;
    return next(error);
  }
}

module.exports = { getStatus };
