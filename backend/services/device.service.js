/**
 * Device service — pairing, daftar device, heartbeat.
 * Tidak mengubah saveSensorData / history logic.
 */

const { getDatabase } = require('../config/firebase');
const deviceStatusEngine = require('./device-status.engine');
const telemetryService = require('./telemetry.service');

/**
 * @param {string} deviceId
 * @returns {Promise<{ exists: boolean, device: object|null }>}
 */
async function loadDevice(deviceId) {
  const id = String(deviceId || '').trim();
  if (!id) {
    return { exists: false, device: null };
  }

  const db = getDatabase();
  const snap = await db.ref(`devices/${id}`).once('value');
  if (!snap.exists()) {
    return { exists: false, device: null };
  }

  const val = snap.val();
  if (val == null || (typeof val === 'object' && !Array.isArray(val) && Object.keys(val).length === 0)) {
    // Node kosong tetap dianggap exists (siap pairing / waiting).
    return { exists: true, device: val && typeof val === 'object' ? val : {} };
  }

  return { exists: true, device: val };
}

/**
 * Ringkasan device untuk API pairing / management.
 * @param {string} deviceId
 * @param {object|null} device
 * @param {boolean} exists
 */
function buildDeviceSummary(deviceId, device, exists) {
  const linkStatus = deviceStatusEngine.resolveLinkStatus(device, { exists });
  const deviceType = deviceStatusEngine.resolveDeviceType(deviceId, device);
  const lastHeartbeatMs = deviceStatusEngine.getLastHeartbeatMs(device);

  return {
    deviceId,
    exists,
    deviceType,
    status: linkStatus,
    lastUpdate: lastHeartbeatMs > 0 ? lastHeartbeatMs : null,
    battery: device && device.battery != null ? Number(device.battery) : null,
    signal: device && device.signal != null ? Number(device.signal) : null,
    gpsFix: exists ? deviceStatusEngine.hasGpsFix(device || {}) : false,
    latitude: device && typeof device.latitude === 'number' ? device.latitude : null,
    longitude: device && typeof device.longitude === 'number' ? device.longitude : null,
  };
}

/**
 * GET /api/device/:deviceId — detail + status engine.
 * @param {string} deviceId
 */
async function getDeviceDetail(deviceId) {
  const id = String(deviceId || '').trim();
  const { exists, device } = await loadDevice(id);
  const summary = buildDeviceSummary(id, device, exists);

  return {
    ...summary,
    // Payload lama tetap tersedia agar client existing tidak rusak.
    data: exists ? (device || {}) : {},
  };
}

/**
 * GET /api/devices — seluruh daftar device.
 */
async function listDevices() {
  const db = getDatabase();
  const snap = await db.ref('devices').once('value');
  const val = snap.val();
  const devices = [];

  if (val && typeof val === 'object') {
    Object.keys(val).forEach((key) => {
      const device = val[key];
      const exists = device != null;
      devices.push(
        buildDeviceSummary(
          key,
          exists && typeof device === 'object' ? device : {},
          exists,
        ),
      );
    });
  }

  devices.sort((a, b) => String(a.deviceId).localeCompare(String(b.deviceId)));
  return devices;
}

/**
 * Parse optional number dari body.
 * @param {unknown} value
 * @returns {{ ok: true, value: number|undefined } | { ok: false, error: string }}
 */
function parseOptionalNumber(value, fieldName) {
  if (value === undefined || value === null || value === '') {
    return { ok: true, value: undefined };
  }
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) {
    return { ok: false, error: `Field "${fieldName}" harus berupa number` };
  }
  return { ok: true, value: n };
}

/**
 * POST /api/device/heartbeat
 * Body: deviceId, battery, signal, gpsFix, latitude, longitude
 *
 * @param {object} body
 */
async function saveHeartbeat(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    const err = new Error('Body JSON tidak valid');
    err.statusCode = 400;
    throw err;
  }

  const deviceId = String(body.deviceId || '').trim();
  if (!deviceId) {
    const err = new Error('Field "deviceId" wajib diisi (string)');
    err.statusCode = 400;
    throw err;
  }

  const { exists, device: prev } = await loadDevice(deviceId);
  if (!exists) {
    const err = new Error('Device tidak ditemukan');
    err.statusCode = 404;
    throw err;
  }

  const battery = parseOptionalNumber(body.battery, 'battery');
  if (!battery.ok) {
    const err = new Error(battery.error);
    err.statusCode = 400;
    throw err;
  }

  const signal = parseOptionalNumber(body.signal, 'signal');
  if (!signal.ok) {
    const err = new Error(signal.error);
    err.statusCode = 400;
    throw err;
  }

  const latitude = parseOptionalNumber(body.latitude, 'latitude');
  if (!latitude.ok) {
    const err = new Error(latitude.error);
    err.statusCode = 400;
    throw err;
  }
  if (latitude.value !== undefined && (latitude.value < -90 || latitude.value > 90)) {
    const err = new Error('Field "latitude" harus antara -90 hingga 90');
    err.statusCode = 400;
    throw err;
  }

  const longitude = parseOptionalNumber(body.longitude, 'longitude');
  if (!longitude.ok) {
    const err = new Error(longitude.error);
    err.statusCode = 400;
    throw err;
  }
  if (longitude.value !== undefined && (longitude.value < -180 || longitude.value > 180)) {
    const err = new Error('Field "longitude" harus antara -180 hingga 180');
    err.statusCode = 400;
    throw err;
  }

  let gpsFix;
  if (body.gpsFix === undefined || body.gpsFix === null || body.gpsFix === '') {
    gpsFix = undefined;
  } else if (typeof body.gpsFix === 'boolean') {
    gpsFix = body.gpsFix;
  } else if (body.gpsFix === 'true' || body.gpsFix === 1 || body.gpsFix === '1') {
    gpsFix = true;
  } else if (body.gpsFix === 'false' || body.gpsFix === 0 || body.gpsFix === '0') {
    gpsFix = false;
  } else {
    const err = new Error('Field "gpsFix" harus berupa boolean');
    err.statusCode = 400;
    throw err;
  }

  const nowMs = Date.now();
  const patch = {
    deviceId,
    lastUpdate: nowMs,
    lastUpdated: nowMs,
    online: true,
  };

  if (battery.value !== undefined) patch.battery = battery.value;
  if (signal.value !== undefined) patch.signal = signal.value;
  if (latitude.value !== undefined) patch.latitude = latitude.value;
  if (longitude.value !== undefined) patch.longitude = longitude.value;

  if (gpsFix !== undefined) {
    patch.gpsFix = gpsFix;
  } else if (latitude.value !== undefined && longitude.value !== undefined) {
    patch.gpsFix = true;
  }

  // Snapshot gabungan untuk hitung status (prev + patch).
  const merged = { ...(prev || {}), ...patch };
  const linkStatus = deviceStatusEngine.resolveLinkStatus(merged, {
    exists: true,
    nowMs,
  });
  patch.linkStatus = linkStatus;

  const db = getDatabase();
  await db.ref(`devices/${deviceId}`).update(patch);

  // Heartbeat backend agar Flutter Application Status tetap segar.
  await telemetryService.touchBackendHeartbeat();

  const summary = buildDeviceSummary(deviceId, merged, true);
  return {
    ...summary,
    status: linkStatus,
    updated: true,
  };
}

/**
 * Tulis ulang linkStatus ke Firebase (additive, tidak ubah field lain).
 * Dipakai opsional setelah sensor save — tanpa mengubah history logic.
 *
 * @param {string} deviceId
 * @param {object} deviceSnapshot
 */
async function writeLinkStatus(deviceId, deviceSnapshot) {
  const id = String(deviceId || '').trim();
  if (!id || !deviceSnapshot) return null;

  const linkStatus = deviceStatusEngine.resolveLinkStatus(deviceSnapshot, {
    exists: true,
  });

  const db = getDatabase();
  await db.ref(`devices/${id}`).update({ linkStatus });
  return linkStatus;
}

module.exports = {
  loadDevice,
  buildDeviceSummary,
  getDeviceDetail,
  listDevices,
  saveHeartbeat,
  writeLinkStatus,
};
