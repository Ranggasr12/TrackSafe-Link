/**
 * Alarm service — handle alarm events from MQTT / REST.
 * Delegates persistence to device.service (alarms/ + history/).
 */

const deviceService = require('./device.service');
const logger = require('../config/logger');

/**
 * Process alarm payload from MQTT topic tracksafe/alarm/{deviceId}
 * @param {string} deviceId
 * @param {object} payload
 */
async function processAlarmMessage(deviceId, payload) {
  const id = String(deviceId || payload.deviceId || '').trim();
  if (!id) {
    const err = new Error('deviceId wajib untuk alarm');
    err.statusCode = 400;
    throw err;
  }

  const body = {
    deviceId: id,
    alarm: payload.alarm !== false,
    status: payload.status || 'DANGER',
    distance: payload.distance,
    battery: payload.battery,
    signal: payload.signal,
  };

  logger.info(`[alarm] Alarm event device=${id} status=${body.status} alarm=${body.alarm}`);

  return deviceService.updateStatus(body);
}

module.exports = {
  processAlarmMessage,
};
