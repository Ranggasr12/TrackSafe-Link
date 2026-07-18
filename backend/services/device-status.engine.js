/**
 * Device Status Engine — Sprint 31.3
 *
 * Menghitung status koneksi perangkat IoT berdasarkan heartbeat terakhir.
 * OFF → WAITING → CONNECTING → ONLINE
 *
 * Tidak mengubah status sensor ESP32 (NORMAL / NOISE / DANGER).
 */

const OFFLINE_THRESHOLD_MS = 30_000;

const LINK_STATUS = Object.freeze({
  OFF: 'OFF',
  WAITING: 'WAITING',
  CONNECTING: 'CONNECTING',
  ONLINE: 'ONLINE',
});

/**
 * Normalisasi timestamp detik/ms → milidetik.
 * @param {unknown} value
 * @returns {number}
 */
function toMillis(value) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return 0;
  return n < 1e12 ? n * 1000 : n;
}

/**
 * Ambil waktu heartbeat terakhir dari field yang tersedia.
 * @param {object|null|undefined} device
 * @returns {number} epoch ms (0 jika tidak ada)
 */
function getLastHeartbeatMs(device) {
  if (!device || typeof device !== 'object') return 0;
  return Math.max(
    toMillis(device.lastUpdate),
    toMillis(device.lastUpdated),
    toMillis(device.timestamp),
  );
}

/**
 * Infer deviceType dari field Firebase atau pola deviceId.
 * @param {string} deviceId
 * @param {object|null|undefined} device
 * @returns {'sender'|'receiver'|'unknown'}
 */
function resolveDeviceType(deviceId, device) {
  const raw = device && device.deviceType != null
    ? String(device.deviceType).toLowerCase().trim()
    : '';
  if (raw === 'sender' || raw === 'receiver') return raw;

  const id = String(deviceId || '').toLowerCase();
  if (id.includes('receiver')) return 'receiver';
  if (id.includes('sender')) return 'sender';
  return 'unknown';
}

/**
 * GPS fix: eksplisit gpsFix, atau koordinat tersedia.
 * @param {object} device
 * @returns {boolean}
 */
function hasGpsFix(device) {
  if (!device || typeof device !== 'object') return false;
  if (device.gpsFix === true) return true;
  if (device.gpsFix === false) return false;
  const lat = device.latitude;
  const lng = device.longitude;
  return typeof lat === 'number' && !Number.isNaN(lat)
    && typeof lng === 'number' && !Number.isNaN(lng);
}

/**
 * Telemetry inti untuk ONLINE: battery + signal.
 * @param {object} device
 * @returns {boolean}
 */
function hasCoreTelemetry(device) {
  if (!device || typeof device !== 'object') return false;
  const battery = device.battery;
  const signal = device.signal;
  return battery != null && battery !== '' && !Number.isNaN(Number(battery))
    && signal != null && signal !== '' && !Number.isNaN(Number(signal));
}

/**
 * Hitung link status dari snapshot device + flag exists.
 *
 * @param {object|null|undefined} device
 * @param {{ exists?: boolean, nowMs?: number }} [options]
 * @returns {'OFF'|'WAITING'|'CONNECTING'|'ONLINE'}
 */
function resolveLinkStatus(device, options = {}) {
  const exists = options.exists !== false && device != null
    && typeof device === 'object';
  const nowMs = options.nowMs != null ? options.nowMs : Date.now();

  if (!exists) return LINK_STATUS.OFF;

  const lastMs = getLastHeartbeatMs(device);
  if (lastMs <= 0) {
    // Node ada di Firebase, belum pernah heartbeat / telemetry.
    return LINK_STATUS.WAITING;
  }

  const ageMs = nowMs - lastMs;
  if (ageMs > OFFLINE_THRESHOLD_MS) {
    return LINK_STATUS.OFF;
  }

  // Heartbeat segar (<30s) — sinkronisasi atau sudah lengkap.
  if (hasCoreTelemetry(device) && hasGpsFix(device)) {
    return LINK_STATUS.ONLINE;
  }

  return LINK_STATUS.CONNECTING;
}

/**
 * Parse string status backend → enum Flutter-compatible.
 * @param {unknown} raw
 * @returns {'OFF'|'WAITING'|'CONNECTING'|'ONLINE'|null}
 */
function normalizeLinkStatus(raw) {
  if (raw == null) return null;
  const s = String(raw).toUpperCase().trim();
  if (
    s === LINK_STATUS.OFF
    || s === LINK_STATUS.WAITING
    || s === LINK_STATUS.CONNECTING
    || s === LINK_STATUS.ONLINE
  ) {
    return s;
  }
  return null;
}

module.exports = {
  OFFLINE_THRESHOLD_MS,
  LINK_STATUS,
  toMillis,
  getLastHeartbeatMs,
  resolveDeviceType,
  hasGpsFix,
  hasCoreTelemetry,
  resolveLinkStatus,
  normalizeLinkStatus,
};
