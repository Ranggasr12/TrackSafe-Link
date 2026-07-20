/**
 * Device service — registrasi, heartbeat, pairing, unpairing, location, status.
 * Backend-managed pairing architecture.
 */

const { getDatabase } = require('../config/firebase');
const deviceStatusEngine = require('./device-status.engine');
const telemetryService = require('./telemetry.service');
const historyService = require('./history.service');

const VALID_DEVICE_TYPES = new Set(['sender', 'receiver']);

/**
 * @param {string} deviceId
 * @returns {Promise<{ exists: boolean, device: object|null }>}
 */
async function loadDevice(deviceId) {
  const id = String(deviceId || '').trim();
  if (!id) return { exists: false, device: null };

  const db = getDatabase();
  const snap = await db.ref(`devices/${id}`).once('value');
  if (!snap.exists()) return { exists: false, device: null };

  const val = snap.val();
  if (val == null || (typeof val === 'object' && !Array.isArray(val) && Object.keys(val).length === 0)) {
    return { exists: true, device: val || {} };
  }
  return { exists: true, device: val };
}

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
    online: device && device.online === true,
    pairedSender: device && device.pairedSender ? device.pairedSender : null,
    pairedReceiver: device && device.pairedReceiver ? device.pairedReceiver : null,
  };
}

async function getDeviceDetail(deviceId) {
  const id = String(deviceId || '').trim();
  const { exists, device } = await loadDevice(id);
  const summary = buildDeviceSummary(id, device, exists);
  return { ...summary, data: exists ? (device || {}) : {} };
}

async function listDevices() {
  const db = getDatabase();
  const snap = await db.ref('devices').once('value');
  const val = snap.val();
  const devices = [];

  if (val && typeof val === 'object') {
    Object.keys(val).forEach((key) => {
      const device = val[key];
      const exists = device != null;
      devices.push(buildDeviceSummary(key, exists && typeof device === 'object' ? device : {}, exists));
    });
  }
  devices.sort((a, b) => String(a.deviceId).localeCompare(String(b.deviceId)));
  return devices;
}

function parseOptionalNumber(value, fieldName) {
  if (value === undefined || value === null || value === '') return { ok: true, value: undefined };
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return { ok: false, error: `Field "${fieldName}" harus berupa number` };
  return { ok: true, value: n };
}

/**
 * POST /api/device/heartbeat — Universal heartbeat for sender AND receiver.
 */
async function saveHeartbeat(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    const err = new Error('Body JSON tidak valid'); err.statusCode = 400; throw err;
  }

  const deviceId = String(body.deviceId || '').trim();
  if (!deviceId) { const err = new Error('Field "deviceId" wajib diisi'); err.statusCode = 400; throw err; }

  const { exists, device: prev } = await loadDevice(deviceId);
  if (!exists) { const err = new Error('Device tidak ditemukan'); err.statusCode = 404; throw err; }

  const battery = parseOptionalNumber(body.battery, 'battery');
  if (!battery.ok) { const err = new Error(battery.error); err.statusCode = 400; throw err; }

  const signal = parseOptionalNumber(body.signal, 'signal');
  if (!signal.ok) { const err = new Error(signal.error); err.statusCode = 400; throw err; }

  const latitude = parseOptionalNumber(body.latitude, 'latitude');
  if (!latitude.ok) { const err = new Error(latitude.error); err.statusCode = 400; throw err; }
  if (latitude.value !== undefined && (latitude.value < -90 || latitude.value > 90)) {
    const err = new Error('Latitude harus antara -90 hingga 90'); err.statusCode = 400; throw err;
  }

  const longitude = parseOptionalNumber(body.longitude, 'longitude');
  if (!longitude.ok) { const err = new Error(longitude.error); err.statusCode = 400; throw err; }
  if (longitude.value !== undefined && (longitude.value < -180 || longitude.value > 180)) {
    const err = new Error('Longitude harus antara -180 hingga 180'); err.statusCode = 400; throw err;
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
    const err = new Error('gpsFix harus boolean'); err.statusCode = 400; throw err;
  }

  // Parse optional distance field
  const distance = parseOptionalNumber(body.distance, 'distance');
  if (!distance.ok) { const err = new Error(distance.error); err.statusCode = 400; throw err; }

  const nowMs = Date.now();
  const wasOffline = prev && prev.online === false;
  const patch = {
    deviceId,
    lastUpdate: nowMs,
    lastUpdated: nowMs,
    lastSeen: nowMs,
    timestamp: Math.floor(nowMs / 1000),
    online: true,
  };

  if (battery.value !== undefined) {
    patch.battery = battery.value;
    patch.batteryWarning = battery.value < 20;
  }
  if (signal.value !== undefined) {
    patch.signal = signal.value;
    patch.gsmSignal = signal.value;
  }
  if (latitude.value !== undefined) patch.latitude = latitude.value;
  if (longitude.value !== undefined) patch.longitude = longitude.value;
  if (distance.value !== undefined) patch.distance = distance.value;

  if (gpsFix !== undefined) patch.gpsFix = gpsFix;
  else if (latitude.value !== undefined && longitude.value !== undefined) patch.gpsFix = true;

  // Preserve deviceType
  if (prev && prev.deviceType) patch.deviceType = prev.deviceType;
  else patch.deviceType = deviceId.toLowerCase().includes('receiver') ? 'receiver' : 'sender';

  const merged = { ...(prev || {}), ...patch };
  const linkStatus = deviceStatusEngine.resolveLinkStatus(merged, { exists: true, nowMs });
  patch.linkStatus = linkStatus;

  // Update status field if provided
  if (body.status) patch.status = String(body.status).toUpperCase().trim();

  const db = getDatabase();
  await db.ref(`devices/${deviceId}`).update(patch);
  await telemetryService.touchBackendHeartbeat();

  if (wasOffline) {
    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.ONLINE,
      deviceId,
      status: patch.status || (prev && prev.status) || 'NORMAL',
      battery: patch.battery,
      signal: patch.signal,
      distance: patch.distance || (prev && prev.distance) || 0,
      description: `Device ${deviceId} is online`,
    });
  }

  // If paired, update the paired device's connection status too
  if (prev && prev.pairedSender) {
    const pairedSnap = await db.ref(`devices/${prev.pairedSender}`).once('value');
    if (pairedSnap.exists()) {
      const pairedData = pairedSnap.val() || {};
      const pairedMerged = { ...pairedData, lastUpdate: nowMs };
      const pairedLink = deviceStatusEngine.resolveLinkStatus(pairedMerged, { exists: true, nowMs });
      await db.ref(`devices/${prev.pairedSender}`).update({ linkStatus: pairedLink, lastUpdate: nowMs });
    }
  }
  if (prev && prev.pairedReceiver) {
    const pairedSnap = await db.ref(`devices/${prev.pairedReceiver}`).once('value');
    if (pairedSnap.exists()) {
      const pairedData = pairedSnap.val() || {};
      const pairedMerged = { ...pairedData, lastUpdate: nowMs };
      const pairedLink = deviceStatusEngine.resolveLinkStatus(pairedMerged, { exists: true, nowMs });
      await db.ref(`devices/${prev.pairedReceiver}`).update({ linkStatus: pairedLink, lastUpdate: nowMs });
    }
  }

  const summary = buildDeviceSummary(deviceId, merged, true);
  return { ...summary, status: linkStatus, updated: true };
}

/**
 * POST /api/device/register — Register sender or receiver.
 */
async function registerDevice(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    const err = new Error('Body JSON tidak valid'); err.statusCode = 400; throw err;
  }

  const deviceId = String(body.deviceId || '').trim();
  if (!deviceId) { const err = new Error('Field "deviceId" wajib diisi'); err.statusCode = 400; throw err; }

  const rawType = String(body.deviceType || '').toLowerCase().trim();
  if (!VALID_DEVICE_TYPES.has(rawType)) {
    const err = new Error('deviceType wajib: "sender" atau "receiver"'); err.statusCode = 400; throw err;
  }

  const { exists, device: existing } = await loadDevice(deviceId);
  const nowMs = Date.now();

  if (exists) {
    // Prevent duplicate registration with wrong type — allow update if same type
    const existingType = existing && existing.deviceType;
    if (existingType && existingType !== rawType) {
      const err = new Error(`Device "${deviceId}" sudah terdaftar sebagai "${existingType}". Tidak bisa diubah menjadi "${rawType}".`);
      err.statusCode = 409; throw err;
    }

    const patch = {
      deviceId,
      deviceType: rawType,
      lastUpdate: nowMs,
      lastUpdated: nowMs,
      online: true,
      registeredAt: existing && existing.registeredAt ? existing.registeredAt : nowMs,
    };
    if (body.latitude !== undefined && typeof body.latitude === 'number') patch.latitude = body.latitude;
    if (body.longitude !== undefined && typeof body.longitude === 'number') patch.longitude = body.longitude;

    const db = getDatabase();
    await db.ref(`devices/${deviceId}`).update(patch);

    return { registered: false, exists: true, deviceId, deviceType: rawType, message: 'Device sudah terdaftar' };
  }

  // New device — create full node
  const deviceData = {
    deviceId,
    deviceType: rawType,
    status: 'NORMAL',
    distance: 0,
    battery: 0,
    signal: 0,
    gsmSignal: 0,
    network: 'unknown',
    firmware: '1.0.0',
    latitude: body.latitude !== undefined && typeof body.latitude === 'number' ? body.latitude : 0,
    longitude: body.longitude !== undefined && typeof body.longitude === 'number' ? body.longitude : 0,
    speed: 0,
    timestamp: Math.floor(nowMs / 1000),
    online: true,
    lastUpdate: nowMs,
    lastUpdated: nowMs,
    registeredAt: nowMs,
    gpsFix: false,
    linkStatus: 'WAITING',
    alarm: false,
    connectionStatus: 'disconnected',
  };

  const db = getDatabase();
  await db.ref(`devices/${deviceId}`).set(deviceData);

  return { registered: true, exists: false, deviceId, deviceType: rawType, message: 'Device berhasil didaftarkan' };
}

/**
 * POST /api/device/pair — Backend-managed pairing.
 */
async function pairDevices(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    const err = new Error('Body JSON tidak valid'); err.statusCode = 400; throw err;
  }

  const senderId = String(body.senderId || '').trim();
  const receiverId = String(body.receiverId || '').trim();

  if (!senderId || !receiverId) {
    const err = new Error('senderId dan receiverId wajib diisi'); err.statusCode = 400; throw err;
  }
  if (senderId === receiverId) {
    const err = new Error('senderId dan receiverId tidak boleh sama'); err.statusCode = 400; throw err;
  }

  const senderCheck = await loadDevice(senderId);
  if (!senderCheck.exists) {
    const err = new Error(`Sender "${senderId}" tidak ditemukan`); err.statusCode = 404; throw err;
  }
  if (senderCheck.device && senderCheck.device.deviceType && senderCheck.device.deviceType !== 'sender') {
    const err = new Error(`"${senderId}" bukan bertipe sender`); err.statusCode = 400; throw err;
  }

  const receiverCheck = await loadDevice(receiverId);
  if (!receiverCheck.exists) {
    const err = new Error(`Receiver "${receiverId}" tidak ditemukan`); err.statusCode = 404; throw err;
  }
  if (receiverCheck.device && receiverCheck.device.deviceType && receiverCheck.device.deviceType !== 'receiver') {
    const err = new Error(`"${receiverId}" bukan bertipe receiver`); err.statusCode = 400; throw err;
  }

  // Check if sender already paired
  if (senderCheck.device && senderCheck.device.pairedReceiver && senderCheck.device.pairedReceiver !== receiverId) {
    const err = new Error(`Sender "${senderId}" sudah ter-pair dengan "${senderCheck.device.pairedReceiver}". Unpair terlebih dahulu.`);
    err.statusCode = 409; throw err;
  }

  // Check if receiver already paired
  if (receiverCheck.device && receiverCheck.device.pairedSender && receiverCheck.device.pairedSender !== senderId) {
    const err = new Error(`Receiver "${receiverId}" sudah ter-pair dengan "${receiverCheck.device.pairedSender}". Unpair terlebih dahulu.`);
    err.statusCode = 409; throw err;
  }

  const nowMs = Date.now();
  const db = getDatabase();

  // Write pairings
  await db.ref(`pairings/${senderId}`).set({ receiverId, pairedAt: nowMs });
  await db.ref(`pairings/${receiverId}`).set({ senderId, pairedAt: nowMs });

  // Update device nodes
  await db.ref(`devices/${senderId}`).update({
    pairedReceiver: receiverId,
    pairedAt: nowMs,
    connectionStatus: 'connected',
  });
  await db.ref(`devices/${receiverId}`).update({
    pairedSender: senderId,
    pairedAt: nowMs,
    connectionStatus: 'connected',
  });

  await historyService.writeHistory({
    eventType: historyService.EVENT_TYPES.PAIRING,
    deviceId: senderId,
    targetDeviceId: receiverId,
    timestamp: Math.floor(nowMs / 1000),
    status: 'NORMAL',
    description: `Device paired: ${senderId} <-> ${receiverId}`,
  });

  await telemetryService.touchBackendHeartbeat();

  return { success: true, senderId, receiverId, pairedAt: nowMs, message: `Pairing berhasil: ${senderId} <-> ${receiverId}` };
}

/**
 * POST /api/device/unpair — Remove pairing between devices.
 */
async function unpairDevices(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    const err = new Error('Body JSON tidak valid'); err.statusCode = 400; throw err;
  }

  const senderId = String(body.senderId || '').trim();
  const receiverId = String(body.receiverId || '').trim();

  if (!senderId && !receiverId) {
    const err = new Error('senderId atau receiverId wajib diisi'); err.statusCode = 400; throw err;
  }

  const db = getDatabase();
  const nowMs = Date.now();

  // If only one ID provided, lookup the paired device
  let actualSender = senderId;
  let actualReceiver = receiverId;

  if (senderId && !receiverId) {
    const snap = await db.ref(`pairings/${senderId}`).once('value');
    if (snap.exists()) {
      const val = snap.val();
      actualReceiver = val.receiverId || '';
    }
  } else if (receiverId && !senderId) {
    const snap = await db.ref(`pairings/${receiverId}`).once('value');
    if (snap.exists()) {
      const val = snap.val();
      actualSender = val.senderId || '';
    }
  }

  // Remove pairings
  if (actualSender) await db.ref(`pairings/${actualSender}`).remove();
  if (actualReceiver) await db.ref(`pairings/${actualReceiver}`).remove();

  // Update device nodes
  if (actualSender) {
    await db.ref(`devices/${actualSender}`).update({
      pairedReceiver: null,
      pairedAt: null,
      connectionStatus: 'disconnected',
    });
  }
  if (actualReceiver) {
    await db.ref(`devices/${actualReceiver}`).update({
      pairedSender: null,
      pairedAt: null,
      connectionStatus: 'disconnected',
    });
  }

  await historyService.writeHistory({
    eventType: historyService.EVENT_TYPES.UNPAIRING,
    deviceId: actualSender || 'unknown',
    targetDeviceId: actualReceiver || 'unknown',
    timestamp: Math.floor(nowMs / 1000),
    status: 'NORMAL',
    description: `Device unpaired: ${actualSender} <-> ${actualReceiver}`,
  });

  await telemetryService.touchBackendHeartbeat();

  return { success: true, senderId: actualSender, receiverId: actualReceiver, message: 'Pairing berhasil dihapus' };
}

/**
 * GET /api/device/pairing/:deviceId
 */
async function getPairingInfo(deviceId) {
  const id = String(deviceId || '').trim();
  if (!id) return { paired: false, pairedDeviceId: null };

  const db = getDatabase();
  const snap = await db.ref(`pairings/${id}`).once('value');
  if (!snap.exists()) return { paired: false, pairedDeviceId: null };

  const val = snap.val();
  const pairedDeviceId = val.senderId || val.receiverId || null;
  return { paired: pairedDeviceId !== null, pairedDeviceId, pairedAt: val.pairedAt || null };
}

/**
 * POST /api/device/location — Update device GPS location.
 */
async function updateLocation(body) {
  if (!body || typeof body !== 'object') {
    const err = new Error('Body JSON tidak valid'); err.statusCode = 400; throw err;
  }

  const deviceId = String(body.deviceId || '').trim();
  if (!deviceId) { const err = new Error('deviceId wajib'); err.statusCode = 400; throw err; }

  const { exists } = await loadDevice(deviceId);
  if (!exists) { const err = new Error('Device tidak ditemukan'); err.statusCode = 404; throw err; }

  if (typeof body.latitude !== 'number' || typeof body.longitude !== 'number') {
    const err = new Error('latitude dan longitude wajib number'); err.statusCode = 400; throw err;
  }
  if (body.latitude < -90 || body.latitude > 90) {
    const err = new Error('Latitude range -90..90'); err.statusCode = 400; throw err;
  }
  if (body.longitude < -180 || body.longitude > 180) {
    const err = new Error('Longitude range -180..180'); err.statusCode = 400; throw err;
  }

  const nowMs = Date.now();
  const db = getDatabase();
  await db.ref(`devices/${deviceId}`).update({
    latitude: body.latitude,
    longitude: body.longitude,
    gpsFix: true,
    lastUpdate: nowMs,
    lastUpdated: nowMs,
    lastSeen: nowMs,
    timestamp: Math.floor(nowMs / 1000),
  });

  return { success: true, deviceId, latitude: body.latitude, longitude: body.longitude };
}

/**
 * POST /api/device/status — Update device status (alarm, connection).
 */
async function updateStatus(body) {
  if (!body || typeof body !== 'object') {
    const err = new Error('Body JSON tidak valid'); err.statusCode = 400; throw err;
  }

  const deviceId = String(body.deviceId || '').trim();
  if (!deviceId) { const err = new Error('deviceId wajib'); err.statusCode = 400; throw err; }

  const { exists, device: prev } = await loadDevice(deviceId);
  if (!exists) { const err = new Error('Device tidak ditemukan'); err.statusCode = 404; throw err; }

  const nowMs = Date.now();
  const patch = {
    lastUpdate: nowMs,
    lastUpdated: nowMs,
    lastSeen: nowMs,
    timestamp: Math.floor(nowMs / 1000),
  };

  if (body.status) patch.status = String(body.status).toUpperCase().trim();
  if (body.alarm !== undefined) patch.alarm = body.alarm === true;
  if (body.connectionStatus) patch.connectionStatus = String(body.connectionStatus).trim();
  if (body.distance !== undefined) patch.distance = Number(body.distance) || 0;
  if (body.battery !== undefined) patch.battery = Number(body.battery) || 0;
  if (body.signal !== undefined) patch.signal = Number(body.signal) || 0;

  const db = getDatabase();
  await db.ref(`devices/${deviceId}`).update(patch);

  // If alarm triggered, write to alarms node
  if (body.alarm === true) {
    const alarmRef = db.ref('alarms').push();
    await alarmRef.set({
      id: alarmRef.key,
      deviceId,
      status: body.status || 'DANGER',
      timestamp: Math.floor(nowMs / 1000),
      acknowledged: false,
    });

    await historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.ALARM,
      deviceId,
      timestamp: Math.floor(nowMs / 1000),
      status: body.status || 'DANGER',
      distance: Number(body.distance) || 0,
      battery: Number(body.battery) || 0,
      signal: Number(body.signal) || 0,
      description: `Alarm triggered by ${deviceId}: ${body.status || 'DANGER'}`,
    });
  }

  return { success: true, deviceId, ...patch };
}

/**
 * GET /api/backend/status — Backend health check endpoint.
 */
async function getBackendStatus() {
  const db = getDatabase();
  const mqttService = require('./mqtt.service');
  const result = {
    success: true,
    name: 'TrackSafe Link Backend',
    version: '2.0.0',
    timestamp: Date.now(),
    firebase: 'checking',
    backend: 'online',
    mqtt: mqttService.getMqttStatus(),
    uptime: process.uptime(),
  };

  try {
    await db.ref('backend/health').set({ timestamp: Date.now() });
    result.firebase = 'connected';
  } catch (e) {
    result.firebase = 'disconnected';
  }

  return result;
}

/**
 * GET /api/history — Get history entries.
 */
async function getHistory(limit = 100) {
  return historyService.getHistory(limit);
}

module.exports = {
  loadDevice,
  buildDeviceSummary,
  getDeviceDetail,
  listDevices,
  saveHeartbeat,
  registerDevice,
  pairDevices,
  unpairDevices,
  getPairingInfo,
  updateLocation,
  updateStatus,
  getBackendStatus,
  getHistory,
};