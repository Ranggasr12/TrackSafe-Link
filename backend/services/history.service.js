/**
 * History service — centralized event recording for TrackSafe.
 */

const { getDatabase } = require('../config/firebase');

const EVENT_TYPES = Object.freeze({
  PAIRING: 'pairing',
  UNPAIRING: 'unpairing',
  ALARM: 'alarm',
  HEARTBEAT_TIMEOUT: 'heartbeat_timeout',
  OFFLINE: 'offline',
  ONLINE: 'online',
  DISTANCE_WARNING: 'distance_warning',
  SENSOR_WARNING: 'sensor_warning',
  BATTERY_WARNING: 'battery_warning',
  RECEIVER_DISCONNECT: 'receiver_disconnect',
  BACKEND_RESTART: 'backend_restart',
  STATUS_CHANGE: 'status_change',
});

/**
 * @param {object} entry
 * @returns {Promise<string|null>} history key
 */
async function writeHistory(entry) {
  const db = getDatabase();
  const nowMs = Date.now();
  const ref = db.ref('history').push();

  const record = {
    id: ref.key,
    eventType: entry.eventType || EVENT_TYPES.STATUS_CHANGE,
    deviceId: entry.deviceId || 'unknown',
    targetDeviceId: entry.targetDeviceId || null,
    timestamp: entry.timestamp != null
      ? Number(entry.timestamp)
      : Math.floor(nowMs / 1000),
    status: entry.status || 'NORMAL',
    distance: Number(entry.distance) || 0,
    battery: entry.battery != null ? Number(entry.battery) : 0,
    signal: entry.signal != null ? Number(entry.signal) : 0,
    description: entry.description || '',
    isAcknowledged: entry.isAcknowledged === true,
    ackTime: entry.ackTime || null,
  };

  await ref.set(record);
  return ref.key;
}

/**
 * @param {number} limit
 */
async function getHistory(limit = 100) {
  const db = getDatabase();
  const snap = await db
    .ref('history')
    .orderByChild('timestamp')
    .limitToLast(limit)
    .once('value');

  const items = [];
  const val = snap.val();
  if (val) {
    Object.keys(val).forEach((key) => {
      items.push({ id: key, ...val[key] });
    });
    items.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
  }
  return items;
}

module.exports = {
  EVENT_TYPES,
  writeHistory,
  getHistory,
};
