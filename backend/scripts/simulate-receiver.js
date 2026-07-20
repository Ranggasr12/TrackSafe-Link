/**
 * Simulator Receiver — register + heartbeat setiap 5 detik.
 *
 * Usage:
 *   npm run dev
 *   npm run simulate:receiver
 *
 * Env:
 *   BASE_URL     default http://localhost:3000
 *   DEVICE_ID    default receiver01
 *   INTERVAL_MS  default 5000
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const BASE_URL = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const DEVICE_ID = process.env.DEVICE_ID || 'receiver01';
const INTERVAL_MS = Number(process.env.INTERVAL_MS) || 5000;

let latitude = -6.914744;
let longitude = 107.60981;
let registered = false;
let tick = 0;

function jitter(value, delta) {
  return value + (Math.random() * 2 - 1) * delta;
}

async function postJson(path, body) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function ensureRegistered() {
  if (registered) return;
  const result = await postJson('/api/device/register', {
    deviceId: DEVICE_ID,
    deviceType: 'receiver',
    latitude,
    longitude,
  });
  registered = result.status === 200 || result.status === 201;
  console.log(`[simulate:receiver] register HTTP ${result.status}`, result.data);
}

async function sendHeartbeat() {
  tick += 1;
  latitude = Math.max(-90, Math.min(90, jitter(latitude, 0.00012)));
  longitude = Math.max(-180, Math.min(180, jitter(longitude, 0.00012)));

  const payload = {
    deviceId: DEVICE_ID,
    battery: 75 + Math.floor(Math.random() * 20),
    signal: 12 + Math.floor(Math.random() * 18),
    latitude: Number(latitude.toFixed(6)),
    longitude: Number(longitude.toFixed(6)),
    gpsFix: true,
    status: 'NORMAL',
  };

  const result = await postJson('/api/device/heartbeat', payload);
  console.log(
    `[simulate:receiver] #${tick} HTTP ${result.status} | bat=${payload.battery} sig=${payload.signal} | ` +
      `${payload.latitude},${payload.longitude}`,
  );
}

async function tickOnce() {
  try {
    await ensureRegistered();
    await sendHeartbeat();
  } catch (error) {
    console.error('[simulate:receiver] error:', error.message);
  }
}

console.log('[simulate:receiver] TrackSafe Receiver simulator');
console.log(`[simulate:receiver] POST ${BASE_URL}/api/device/heartbeat every ${INTERVAL_MS}ms`);
console.log(`[simulate:receiver] deviceId=${DEVICE_ID}`);
console.log('[simulate:receiver] Ctrl+C to stop\n');

tickOnce();
setInterval(tickOnce, INTERVAL_MS);
