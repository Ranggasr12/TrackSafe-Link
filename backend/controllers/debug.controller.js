const telemetryService = require('../services/telemetry.service');

/**
 * GET /api/debug/device/:deviceId
 * Mode pengujian E2E — baca snapshot device dari Firebase.
 */
async function getDebugDevice(req, res) {
  try {
    const { deviceId } = req.params;
    if (!deviceId || String(deviceId).trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'deviceId wajib',
      });
    }

    const data = await telemetryService.getDevice(deviceId.trim());
    if (!data) {
      return res.status(404).json({
        success: false,
        error: `Device "${deviceId}" tidak ditemukan`,
        serverTime: Date.now(),
      });
    }

    return res.status(200).json({
      deviceId: data.deviceId ?? deviceId,
      status: data.status ?? null,
      distance: data.distance ?? null,
      battery: data.battery ?? null,
      signal: data.signal ?? null,
      latitude: data.latitude ?? null,
      longitude: data.longitude ?? null,
      speed: data.speed ?? null,
      timestamp: data.timestamp ?? null,
      online: data.online ?? null,
      lastUpdated: data.lastUpdated ?? null,
      serverTime: Date.now(),
    });
  } catch (error) {
    console.error('[debug/device] error:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message || 'Internal Server Error',
      serverTime: Date.now(),
    });
  }
}

/**
 * GET /api/debug/history
 * Mode pengujian E2E — 20 history terbaru.
 */
async function getDebugHistory(_req, res) {
  try {
    const data = await telemetryService.getHistory(20);
    return res.status(200).json({
      success: true,
      count: data.length,
      data,
      serverTime: Date.now(),
    });
  } catch (error) {
    console.error('[debug/history] error:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message || 'Internal Server Error',
      serverTime: Date.now(),
    });
  }
}

module.exports = {
  getDebugDevice,
  getDebugHistory,
};
