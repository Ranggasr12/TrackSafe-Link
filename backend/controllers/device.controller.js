const deviceService = require('../services/device.service');
const logger = require('../config/logger');

/**
 * GET /api/device/:deviceId
 */
async function getDevice(req, res, next) {
  try {
    const { deviceId } = req.params;
    if (!deviceId || String(deviceId).trim() === '') {
      return res.status(400).json({ success: false, error: 'deviceId wajib' });
    }
    const detail = await deviceService.getDeviceDetail(deviceId);
    return res.status(200).json({ success: true, ...detail });
  } catch (error) {
    logger.error('[device] getDevice error:', error.message);
    error.statusCode = error.statusCode || 500;
    return next(error);
  }
}

/**
 * GET /api/device/list
 * GET /api/devices (alias)
 */
async function getDevices(req, res, next) {
  try {
    const devices = await deviceService.listDevices();
    return res.status(200).json({ success: true, count: devices.length, devices });
  } catch (error) {
    logger.error('[device] getDevices error:', error.message);
    error.statusCode = error.statusCode || 500;
    return next(error);
  }
}

/**
 * POST /api/device/heartbeat
 */
async function postHeartbeat(req, res, next) {
  try {
    const result = await deviceService.saveHeartbeat(req.body);
    logger.debug(`[device] heartbeat ${result.deviceId} | ${result.status} | bat=${result.battery} sig=${result.signal} gps=${result.gpsFix}`);
    return res.status(200).json({ success: true, updated: true, ...result, serverTime: Date.now() });
  } catch (error) {
    logger.error('[device] heartbeat error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({ success: false, updated: false, error: error.message });
  }
}

/**
 * POST /api/device/register
 */
async function postRegister(req, res, next) {
  try {
    const result = await deviceService.registerDevice(req.body);
    logger.debug(`[device] register ${result.deviceId} | ${result.deviceType} | ${result.message}`);
    return res.status(result.registered ? 201 : 200).json({ success: true, ...result });
  } catch (error) {
    logger.error('[device] register error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({ success: false, error: error.message });
  }
}

/**
 * POST /api/device/pair
 */
async function postPair(req, res, next) {
  try {
    const result = await deviceService.pairDevices(req.body);
    logger.debug(`[device] pair ${result.senderId} <-> ${result.receiverId}`);
    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    logger.error('[device] pair error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({ success: false, error: error.message });
  }
}

/**
 * POST /api/device/unpair
 */
async function postUnpair(req, res, next) {
  try {
    const result = await deviceService.unpairDevices(req.body);
    logger.debug(`[device] unpair ${result.senderId} <-> ${result.receiverId}`);
    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    logger.error('[device] unpair error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({ success: false, error: error.message });
  }
}

/**
 * GET /api/device/pairing/:deviceId
 */
async function getPairing(req, res, next) {
  try {
    const { deviceId } = req.params;
    if (!deviceId || String(deviceId).trim() === '') {
      return res.status(400).json({ success: false, error: 'deviceId wajib' });
    }
    const info = await deviceService.getPairingInfo(deviceId);
    return res.status(200).json({ success: true, deviceId, ...info });
  } catch (error) {
    logger.error('[device] getPairing error:', error.message);
    error.statusCode = error.statusCode || 500;
    return next(error);
  }
}

/**
 * POST /api/device/location
 */
async function postLocation(req, res, next) {
  try {
    const result = await deviceService.updateLocation(req.body);
    logger.debug(`[device] location ${result.deviceId} | lat=${result.latitude} lng=${result.longitude}`);
    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    logger.error('[device] location error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({ success: false, error: error.message });
  }
}

/**
 * POST /api/device/status
 */
async function postStatus(req, res, next) {
  try {
    const result = await deviceService.updateStatus(req.body);
    logger.debug(`[device] status ${result.deviceId} | alarm=${result.alarm} status=${result.status}`);
    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    logger.error('[device] status error:', error.message);
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({ success: false, error: error.message });
  }
}

/**
 * GET /api/backend/status
 */
async function getBackendStatus(req, res, next) {
  try {
    const status = await deviceService.getBackendStatus();
    return res.status(200).json(status);
  } catch (error) {
    logger.error('[backend] status error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * GET /api/backend/history
 * GET /api/history
 */
async function getHistory(req, res, next) {
  try {
    const limit = parseInt(req.query.limit, 10) || 100;
    if (limit < 1 || limit > 1000) {
      return res.status(400).json({ success: false, error: 'limit 1-1000' });
    }
    const data = await deviceService.getHistory(limit);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    logger.error('[history] error:', error.message);
    error.statusCode = error.statusCode || 500;
    return next(error);
  }
}

module.exports = {
  getDevice,
  getDevices,
  postHeartbeat,
  postRegister,
  postPair,
  postUnpair,
  getPairing,
  postLocation,
  postStatus,
  getBackendStatus,
  getHistory,
};