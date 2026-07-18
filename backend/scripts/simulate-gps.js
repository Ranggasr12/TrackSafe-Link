/**
 * Simulator GPS E2E — kirim payload ESP32 lengkap ke POST /api/sensor
 * setiap 5 detik dengan koordinat yang bergeser sedikit.
 *
 * Development Only — jangan dipakai di production Vercel.
 *
 * Usage:
 *   1. Jalankan backend: npm run dev
 *   2. npm run simulate:gps
 *
 * Env opsional:
 *   BASE_URL   default http://localhost:3000  (Development Only)
 *   DEVICE_ID  default sender01
 *   INTERVAL_MS default 5000
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

// Development Only — default localhost untuk uji lokal
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const DEVICE_ID = process.env.DEVICE_ID || 'sender01';
const INTERVAL_MS = Number(process.env.INTERVAL_MS) || 5000;

const STATUSES = ['NORMAL', 'NOISE', 'DANGER'];

/** Titik awal sekitar Bandung (sama seperti MapScreen). */
let latitude = -6.914744;
let longitude = 107.60981;
let tick = 0;

function jitter(value, delta) {
  return value + (Math.random() * 2 - 1) * delta;
}

function nextPayload() {
  tick += 1;

  // Geser koordinat sedikit agar marker Flutter bergerak
  latitude = jitter(latitude, 0.00018);
  longitude = jitter(longitude, 0.00018);

  // Clamp ke range valid
  latitude = Math.max(-90, Math.min(90, latitude));
  longitude = Math.max(-180, Math.min(180, longitude));

  const status = STATUSES[Math.floor(Math.random() * STATUSES.length)];
  // Bias ke NORMAL agar uji marker lebih sering "aman"
  const statusFinal = Math.random() < 0.6 ? 'NORMAL' : status;
  const speed = Math.round(Math.random() * 25 * 10) / 10;

  return {
    deviceId: DEVICE_ID,
    status: statusFinal,
    distance: 80 + Math.floor(Math.random() * 200),
    battery: 70 + Math.floor(Math.random() * 30),
    signal: 15 + Math.floor(Math.random() * 15),
    latitude: Number(latitude.toFixed(6)),
    longitude: Number(longitude.toFixed(6)),
    speed,
    timestamp: Math.floor(Date.now() / 1000),
  };
}

async function sendOnce() {
  const payload = nextPayload();
  const url = `${BASE_URL.replace(/\/$/, '')}/api/sensor`;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const body = await res.json().catch(() => ({}));
    console.log(
      `[simulate:gps] #${tick} HTTP ${res.status} | ${payload.status} | ` +
        `${payload.latitude},${payload.longitude} | speed=${payload.speed} | ` +
        `${JSON.stringify(body)}`,
    );
  } catch (error) {
    console.error(
      `[simulate:gps] #${tick} gagal — pastikan backend jalan di ${BASE_URL}`,
      error.message,
    );
  }
}

console.log('[simulate:gps] TrackSafe GPS simulator');
console.log(`[simulate:gps] POST ${BASE_URL}/api/sensor setiap ${INTERVAL_MS}ms`);
console.log(`[simulate:gps] deviceId=${DEVICE_ID}`);
console.log('[simulate:gps] Ctrl+C untuk berhenti\n');

sendOnce();
setInterval(sendOnce, INTERVAL_MS);
