/**
 * Telemetry service — simpan data ESP32 ke Firebase RTDB.
 * TIDAK menjalankan rule-based (status dari ESP32 apa adanya).
 */

const { getDatabase } = require('../config/firebase');
const deviceStatusEngine = require('./device-status.engine');
const historyService = require('./history.service');

const VALID_STATUS = new Set(['NORMAL', 'NOISE', 'DANGER']);

/** MQTT / rule aliases → Firebase / Flutter status. */
const MQTT_STATUS_ALIASES = Object.freeze({
  SAFE: 'NORMAL',
  TRAIN: 'DANGER',
});

function normalizeStatus(raw) {
  const s = String(raw || '').toUpperCase().trim();
  if (VALID_STATUS.has(s)) return s;
  if (MQTT_STATUS_ALIASES[s]) return MQTT_STATUS_ALIASES[s];
  return null;
}

/**
 * Map rule number (ESP32) ke status Firebase.
 * Rule 1: SAFE → NORMAL, Rule 2: NOISE, Rule 3: TRAIN → DANGER
 * @param {unknown} rule
 * @returns {'NORMAL'|'NOISE'|'DANGER'|null}
 */
function normalizeRuleStatus(rule) {
  const r = Number(rule);
  if (r === 1) return 'NORMAL';
  if (r === 2) return 'NOISE';
  if (r === 3) return 'DANGER';
  return null;
}

/**
 * Resolve status from MQTT payload (status field or rule fallback).
 * @param {object} payload
 * @returns {'NORMAL'|'NOISE'|'DANGER'|null}
 */
function resolveMqttStatus(payload) {
  const fromStatus = normalizeStatus(payload && payload.status);
  if (fromStatus) return fromStatus;
  return normalizeRuleStatus(payload && payload.rule);
}

/**
 * GPS optional untuk jalur MQTT — pakai koordinat existing device jika tidak dikirim.
 * @param {object} payload
 * @param {object} existingDevice
 */
function resolveGpsForMqtt(payload, existingDevice) {
  const existing = existingDevice || {};
  const hasLat = typeof payload.latitude === 'number' && !Number.isNaN(payload.latitude);
  const hasLng = typeof payload.longitude === 'number' && !Number.isNaN(payload.longitude);

  const latitude = hasLat ? payload.latitude : (Number(existing.latitude) || 0);
  const longitude = hasLng ? payload.longitude : (Number(existing.longitude) || 0);
  const speed = typeof payload.speed === 'number' && !Number.isNaN(payload.speed)
    ? payload.speed
    : (Number(existing.speed) || 0);
  const timestamp = typeof payload.timestamp === 'number' && payload.timestamp > 0
    ? payload.timestamp
    : Math.floor(Date.now() / 1000);

  return validateGpsFields({ latitude, longitude, speed, timestamp });
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

  const deviceRef = db.ref(`devices/${deviceId}`);
  const prevSnap = await deviceRef.once('value');
  const prevStatus = prevSnap.exists()
    ? normalizeStatus((prevSnap.val() || {}).status)
    : null;

  const existingDevice = prevSnap.exists() ? (prevSnap.val() || {}) : {};
  const deviceType = existingDevice.deviceType ||
    (deviceId.toLowerCase().includes('receiver') ? 'receiver' : 'sender');

  const nowMs = Date.now();
  const wasOffline = existingDevice.online === false;

  const data = {
    deviceId,
    deviceType,
    status,
    distance: Number(payload.distance) || 0,
    battery: Number(payload.battery) || 0,
    signal: Number(payload.signal) || 0,
    gsmSignal: Number(payload.signal) || 0,
    latitude: gps.latitude,
    longitude: gps.longitude,
    speed: gps.speed,
    timestamp: gps.timestamp || Math.floor(nowMs / 1000),
    online: true,
    lastUpdated: nowMs,
    lastUpdate: nowMs,
    lastSeen: nowMs,
    gpsFix: hasLatLngInPayload(payload) || (gps.latitude !== 0 || gps.longitude !== 0),
    alarm: payload.alarm === true || status === 'DANGER',
  };

  if (payload.limitSwitch !== undefined) {
    data.limitSwitch = payload.limitSwitch === true
      || payload.limitSwitch === 1
      || String(payload.limitSwitch).toUpperCase() === 'HIGH';
  }
  if (payload.rule !== undefined) data.rule = Number(payload.rule) || 0;

  // Additive: linkStatus dari Device Status Engine (tidak mengubah history / sensor rules).
  data.linkStatus = deviceStatusEngine.resolveLinkStatus(data, { exists: true });

  await deviceRef.update(data);

  if (!prevSnap.exists()) {
    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.ONLINE,
      deviceId,
      status,
      distance: data.distance,
      battery: data.battery,
      signal: data.signal,
      description: `Device ${deviceId} auto-registered via sensor`,
    });
  } else if (wasOffline) {
    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.ONLINE,
      deviceId,
      status,
      distance: data.distance,
      battery: data.battery,
      signal: data.signal,
      description: `Device ${deviceId} back online`,
    });
  }

  if (prevStatus !== status) {
    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.STATUS_CHANGE,
      deviceId,
      status,
      distance: data.distance,
      battery: data.battery,
      signal: data.signal,
      description: `Status changed to ${status}`,
    });
  }

  if (status === 'NOISE') {
    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.SENSOR_WARNING,
      deviceId,
      status,
      distance: data.distance,
      battery: data.battery,
      signal: data.signal,
      description: `Sensor noise detected on ${deviceId}`,
    });
  }

  if (status === 'DANGER') {
    const alarmRef = db.ref('alarms').push();
    await alarmRef.set({
      id: alarmRef.key,
      deviceId,
      status,
      timestamp: data.timestamp,
      acknowledged: false,
    });

    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.ALARM,
      deviceId,
      status,
      distance: data.distance,
      battery: data.battery,
      signal: data.signal,
      description: `Danger alarm on ${deviceId}`,
    });
  }

  if (data.battery < 20 && (existingDevice.battery == null || Number(existingDevice.battery) >= 20)) {
    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.BATTERY_WARNING,
      deviceId,
      status,
      distance: data.distance,
      battery: data.battery,
      signal: data.signal,
      description: `Low battery on ${deviceId}: ${data.battery}%`,
    });
  }

  const prevDistance = Number(existingDevice.distance) || 0;
  if (data.distance > 0 && data.distance < 150 && (prevDistance === 0 || prevDistance >= 150)) {
    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.DISTANCE_WARNING,
      deviceId,
      status,
      distance: data.distance,
      battery: data.battery,
      signal: data.signal,
      description: `Distance warning on ${deviceId}: ${data.distance}cm`,
    });
  }

  await touchBackendHeartbeat();

  return data;
}

function hasLatLngInPayload(payload) {
  return typeof payload.latitude === 'number' && !Number.isNaN(payload.latitude)
    && typeof payload.longitude === 'number' && !Number.isNaN(payload.longitude);
}

/**
 * Simpan telemetry Sender dari MQTT (GPS opsional, status SAFE/TRAIN didukung).
 * @param {object} payload
 * @returns {Promise<object>}
 */
async function saveMqttSenderData(payload) {
  const deviceId = String(payload.deviceId || '').trim();
  if (!deviceId) {
    const err = new Error('Field "deviceId" tidak valid');
    err.statusCode = 400;
    throw err;
  }

  const status = resolveMqttStatus(payload);
  if (!status) {
    const err = new Error('Field "status" atau "rule" tidak valid');
    err.statusCode = 400;
    throw err;
  }

  const db = getDatabase();
  const deviceRef = db.ref(`devices/${deviceId}`);
  const prevSnap = await deviceRef.once('value');
  const existingDevice = prevSnap.exists() ? (prevSnap.val() || {}) : {};

  const gps = resolveGpsForMqtt(payload, existingDevice);
  if (!gps.ok) {
    const err = new Error(gps.error);
    err.statusCode = 400;
    throw err;
  }

  const enriched = {
    ...payload,
    deviceId,
    deviceType: 'sender',
    status,
    latitude: gps.latitude,
    longitude: gps.longitude,
    speed: gps.speed,
    timestamp: gps.timestamp,
  };

  return saveSensorData(enriched);
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
  return historyService.getHistory(limit);
}

module.exports = {
  saveSensorData,
  saveMqttSenderData,
  touchBackendHeartbeat,
  pingFirebase,
  getDevice,
  getHistory,
  normalizeStatus,
  normalizeRuleStatus,
  resolveMqttStatus,
  validateGpsFields,
  resolveGpsForMqtt,
};