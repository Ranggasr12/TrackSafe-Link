/**
 * Register sender01 + receiver01 and optionally pair them.
 *
 * Usage:
 *   npm run simulate:devices
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const BASE_URL = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const SENDER_ID = process.env.SENDER_ID || 'sender01';
const RECEIVER_ID = process.env.RECEIVER_ID || 'receiver01';
const AUTO_PAIR = process.env.AUTO_PAIR !== 'false';

async function postJson(path, body) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function main() {
  console.log(`[simulate:devices] Registering ${SENDER_ID} and ${RECEIVER_ID}...`);

  const sender = await postJson('/api/device/register', {
    deviceId: SENDER_ID,
    deviceType: 'sender',
    latitude: -6.914744,
    longitude: 107.60981,
  });
  console.log('[simulate:devices] sender', sender.status, sender.data);

  const receiver = await postJson('/api/device/register', {
    deviceId: RECEIVER_ID,
    deviceType: 'receiver',
    latitude: -6.914800,
    longitude: 107.609900,
  });
  console.log('[simulate:devices] receiver', receiver.status, receiver.data);

  if (AUTO_PAIR) {
    const pair = await postJson('/api/device/pair', {
      senderId: SENDER_ID,
      receiverId: RECEIVER_ID,
    });
    console.log('[simulate:devices] pair', pair.status, pair.data);
  }

  const list = await fetch(`${BASE_URL}/api/device/list`);
  const devices = await list.json();
  console.log('[simulate:devices] device list:', JSON.stringify(devices, null, 2));
}

main().catch((e) => {
  console.error('[simulate:devices] failed:', e.message);
  process.exit(1);
});
