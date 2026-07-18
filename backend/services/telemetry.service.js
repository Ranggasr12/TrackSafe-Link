/**
 * Telemetry service — simpan data ESP32 ke Firebase RTDB.
 * TIDAK menjalankan rule-based (status dari ESP32 apa adanya).
 */

const { getDatabase } = require('../config/firebase');
const deviceStatusEngine = require('./device-status.engine');

const VALID_STATUS = new Set(['NORMAL', 'NOISE', 'DANGER']);

function normalizeStatus(raw) {
  const s = String(raw || '').toUpperCase().trim();
  if (VALID_STATUS.has(s)) return s;
  return null;
}

/**
 * Validasi field GPS wajib dari ESP32.
 * @param {object} payload
 * @returns {{ ok: true, latitude: number, longitude: number, speed: number, timestamp: number }
 *   | { ok: false, error: string }}
 */
function validateGpsFields(payload) {
  const { latitude, longitude, speed, timestamp } = payload;

  if (typeof latitude !== 'number' || Number.isNaN(latitude)) {
    return { ok: false, error: 'Field "latitude" wajib berupa number' };
  }
  if (latitude < -90 || latitude > 90) {
    return {
      ok: false,
      error: 'Field "latitude" harus antara -90 hingga 90',
    };
  }

  if (typeof longitude !== 'number' || Number.isNaN(longitude)) {
    return { ok: false, error: 'Field "longitude" wajib berupa number' };
  }
  if (longitude < -180 || longitude > 180) {
    return {
      ok: false,
      error: 'Field "longitude" harus antara -180 hingga 180',
    };
  }

  if (typeof speed !== 'number' || Number.isNaN(speed)) {
    return { ok: false, error: 'Field "speed" wajib berupa number' };
  }
  if (speed < 0) {
    return { ok: false, error: 'Field "speed" harus >= 0' };
  }

  if (typeof timestamp !== 'number' || Number.isNaN(timestamp)) {
    return { ok: false, error: 'Field "timestamp" wajib berupa number' };
  }
  if (timestamp <= 0) {
    return { ok: false, error: 'Field "timestamp" harus > 0' };
  }

  return {
    ok: true,
    latitude,
    longitude,
    speed,
    timestamp,
  };
}

/**
 * @param {object} payload
 * @returns {Promise<object>}
 */
async function saveSensorData(payload) {
  const db = getDatabase();

  const deviceId = String(payload.deviceId || 'sender01').trim();
  const status = normalizeStatus(payload.status);

  if (!status) {
    const err = new Error(
      'Field "status" wajib NORMAL | NOISE | DANGER',
    );
    err.statusCode = 400;
    throw err;
  }

  if (!deviceId) {
    const err = new Error('Field "deviceId" tidak valid');
    err.statusCode = 400;
    throw err;
  }

  const gps = validateGpsFields(payload);
  if (!gps.ok) {
    const err = new Error(gps.error);
    err.statusCode = 400;
    throw err;
  }

  const data = {
    deviceId,
    status,
    distance: Number(payload.distance) || 0,
    battery: Number(payload.battery) || 0,
    signal: Number(payload.signal) || 0,
    latitude: gps.latitude,
    longitude: gps.longitude,
    speed: gps.speed,
    timestamp: gps.timestamp,
    online: true,
    lastUpdated: Date.now(),
    lastUpdate: Date.now(),
    gpsFix: true,
  };

  // Additive: linkStatus dari Device Status Engine (tidak mengubah history / sensor rules).
  data.linkStatus = deviceStatusEngine.resolveLinkStatus(data, { exists: true });

  const deviceRef = db.ref(`devices/${deviceId}`);
  const prevSnap = await deviceRef.once('value');
  const prevStatus = prevSnap.exists()
    ? normalizeStatus((prevSnap.val() || {}).status)
    : null;

  await deviceRef.update(data);

  // History hanya saat status berubah (hindari spam polling ESP32)
  if (prevStatus !== status) {
    const historyRef = db.ref('history').push();
    await historyRef.set({
      id: historyRef.key,
      ...data,
    });
  }

  await touchBackendHeartbeat();

  return data;
}

/**
 * Tandai backend online di Firebase (dibaca Flutter).
 */
async function touchBackendHeartbeat() {
  const db = getDatabase();
  await db.ref('backend/status').set({
    online: true,
    timestamp: Date.now(),
  });
}

/**
 * Verifikasi koneksi Firebase dengan write kecil.
 */
async function pingFirebase() {
  const db = getDatabase();
  await db.ref('backend/status').set({
    online: true,
    timestamp: Date.now(),
  });
  return true;
}

/**
 * @param {string} deviceId
 */
async function getDevice(deviceId) {
  const db = getDatabase();
  const snap = await db.ref(`devices/${deviceId}`).once('value');
  return snap.val() || null;
}

/**
 * @param {number} limit
 */
async function getHistory(limit = 50) {
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
  saveSensorData,
  touchBackendHeartbeat,
  pingFirebase,
  getDevice,
  getHistory,
  normalizeStatus,
  validateGpsFields,
};
