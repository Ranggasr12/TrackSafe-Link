const deviceService = require('../services/device.service');
const logger = require('../config/logger');

/**
 * GET /api/device/:deviceId
 *
 * Response (Sprint 31.3):
 *   exists, deviceType, status
 *
 * Tetap menyertakan `success` + `data` agar client lama kompatibel.
 */
async function getDevice(req, res, next) {
  try {
    const { deviceId } = req.params;
    if (!deviceId || String(deviceId).trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'deviceId wajib',
      });
    }

    const detail = await deviceService.getDeviceDetail(deviceId);

    return res.status(200).json({
      success: true,
      exists: detail.exists,
      deviceType: detail.deviceType,
      status: detail.status,
      deviceId: detail.deviceId,
      data: detail.data,
    });
  } catch (error) {
    logger.error('[device] getDevice error:', error.message);
    error.statusCode = error.statusCode || 500;
    return next(error);
  }
}

/**
 * GET /api/devices
 * Daftar seluruh device di Firebase `devices/`.
 */
async function getDevices(req, res, next) {
  try {
    const devices = await deviceService.listDevices();
    return res.status(200).json({
      success: true,
      count: devices.length,
      devices,
    });
  } catch (error) {
    logger.error('[device] getDevices error:', error.message);
    error.statusCode = error.statusCode || 500;
    return next(error);
  }
}

/**
 * POST /api/device/heartbeat
 * Body: deviceId, battery, signal, gpsFix, latitude, longitude
 */
async function postHeartbeat(req, res, next) {
  try {
    const result = await deviceService.saveHeartbeat(req.body);

    // Debug log — Development Only (hindari spam heartbeat di production).
    logger.debug(
      `[device] heartbeat ${result.deviceId} | ${result.status} | ` +
        `bat=${result.battery} sig=${result.signal} gps=${result.gpsFix}`,
    );

    return res.status(200).json({
      success: true,
      updated: true,
      deviceId: result.deviceId,
      exists: result.exists,
      deviceType: result.deviceType,
      status: result.status,
      lastUpdate: result.lastUpdate,
      battery: result.battery,
      signal: result.signal,
      gpsFix: result.gpsFix,
      serverTime: Date.now(),
    });
  } catch (error) {
    logger.error('[device] heartbeat error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({
      success: false,
      updated: false,
      error: error.message || 'Internal Server Error',
    });
  }
}

module.exports = {
  getDevice,
  getDevices,
  postHeartbeat,
};
