const telemetryService = require('../services/telemetry.service');
const { isFirebaseReady } = require('../config/firebase');

/**
 * GET /api/status — legacy health + Firebase ping
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

/**
 * GET /health — Railway health check
 * Response: { success, mqtt, firebase, uptime, timestamp }
 */
async function getHealth(req, res) {
  const mqttService = require('../services/mqtt.service');

  let firebase = 'disconnected';
  try {
    if (isFirebaseReady()) {
      await telemetryService.pingFirebase();
      firebase = 'connected';
    }
  } catch (_error) {
    firebase = 'disconnected';
  }

  const mqtt = mqttService.getMqttHealthLabel();

  const httpStatus = firebase === 'connected' ? 200 : 503;

  return res.status(httpStatus).json({
    success: firebase === 'connected',
    mqtt,
    firebase,
    uptime: process.uptime(),
    timestamp: Date.now(),
  });
}

module.exports = { getStatus, getHealth };
