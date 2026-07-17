const telemetryService = require('../services/telemetry.service');

/**
 * POST /api/sensor
 * Body dari ESP32:
 * {
 *   "deviceId":"sender01",
 *   "status":"NORMAL"|"NOISE"|"DANGER",
 *   "distance":125,
 *   "battery":93,
 *   "signal":22,
 *   "latitude":-6.914744,
 *   "longitude":107.609810,
 *   "speed":4.2,
 *   "timestamp":1720000000
 * }
 *
 * Backend hanya:
 * 1. Validasi payload (termasuk GPS)
 * 2. Simpan/update Firebase RTDB
 * 3. Tambah History jika status berubah
 * 4. Return JSON Success
 *
 * Backend TIDAK mengubah status, tidak menghitung rule-based,
 * tidak menghitung alarm. Rule-based ada di ESP32.
 */
async function postSensor(req, res, next) {
  try {
    const payload = req.body;

    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return res.status(400).json({
        success: false,
        error: 'Body JSON tidak valid',
      });
    }

    if (!payload.deviceId || typeof payload.deviceId !== 'string' || payload.deviceId.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Field "deviceId" wajib diisi (string)',
      });
    }

    const normalized = telemetryService.normalizeStatus(payload.status);
    if (!normalized) {
      return res.status(400).json({
        success: false,
        error: 'Field "status" wajib: NORMAL | NOISE | DANGER',
      });
    }

    const gps = telemetryService.validateGpsFields(payload);
    if (!gps.ok) {
      return res.status(400).json({
        success: false,
        error: gps.error,
      });
    }

    const saved = await telemetryService.saveSensorData(payload);

    console.log(
      `[sensor] saved ${saved.deviceId} | ${saved.status} | ` +
        `${saved.distance}cm | GPS ${saved.latitude},${saved.longitude} | ` +
        `speed ${saved.speed}`,
    );

    return res.status(200).json({
      success: true,
      received: true,
      deviceId: saved.deviceId,
      serverTime: Date.now(),
    });
  } catch (error) {
    console.error('[sensor] error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({
      success: false,
      received: false,
      error: error.message || 'Internal Server Error',
    });
  }
}

/**
 * GET /api/device/:deviceId
 */
async function getDevice(req, res, next) {
  try {
    const { deviceId } = req.params;
    if (!deviceId) {
      return res.status(400).json({
        success: false,
        error: 'deviceId wajib',
      });
    }

    const data = await telemetryService.getDevice(deviceId);
    return res.status(200).json({
      success: true,
      data: data || {},
    });
  } catch (error) {
    console.error('[device] error:', error.message);
    error.statusCode = 500;
    return next(error);
  }
}

/**
 * GET /api/history?limit=50
 */
async function getHistory(req, res, next) {
  try {
    const limit = parseInt(req.query.limit, 10) || 50;
    if (limit < 1 || limit > 500) {
      return res.status(400).json({
        success: false,
        error: 'limit harus antara 1–500',
      });
    }

    const data = await telemetryService.getHistory(limit);
    return res.status(200).json({
      success: true,
      data,
    });
  } catch (error) {
    console.error('[history] error:', error.message);
    error.statusCode = 500;
    return next(error);
  }
}

module.exports = {
  postSensor,
  getDevice,
  getHistory,
};
