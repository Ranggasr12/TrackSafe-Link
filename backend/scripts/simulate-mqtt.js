/**
 * MQTT simulator — kirim payload Sender + Receiver ke HiveMQ.
 * Produksi ESP32 memakai MQTT; REST API hanya untuk testing.
 *
 * Usage:
 *   npm run mqtt          # terminal 1 — backend subscriber
 *   npm run simulate:mqtt # terminal 2 — publish test data
 *
 * Env:
 *   MQTT_HOST, MQTT_PORT, MQTT_USERNAME, MQTT_PASSWORD
 *   SENDER_ID   default sender01
 *   RECEIVER_ID default receiver01
 *   INTERVAL_MS default 1000 (telemetry)
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const mqtt = require('mqtt');

const HOST = process.env.MQTT_HOST || 'broker.hivemq.com';
const PORT = Number(process.env.MQTT_PORT || 1883);
const useTls = PORT === 8883;
const protocol = useTls ? 'mqtts' : 'mqtt';
const BROKER_URL = `${protocol}://${HOST}:${PORT}`;

const SENDER_ID = process.env.SENDER_ID || 'sender01';
const RECEIVER_ID = process.env.RECEIVER_ID || 'receiver01';
const TELEMETRY_MS = Number(process.env.INTERVAL_MS) || 1000;
const HEARTBEAT_MS = 10_000;

const clientId = process.env.MQTT_CLIENT_ID
  ? `${process.env.MQTT_CLIENT_ID}-sim`
  : `tracksafe-sim-${Math.random().toString(16).slice(2, 8)}`;

const options = {
  clientId,
  clean: true,
  reconnectPeriod: 5000,
};

if (process.env.MQTT_USERNAME) options.username = process.env.MQTT_USERNAME;
if (process.env.MQTT_PASSWORD) options.password = process.env.MQTT_PASSWORD;

let tick = 0;
let lastRule = 1;
let distance = 180;

function evaluateRule(dist, limitHigh) {
  if (dist > 150 && !limitHigh) return { rule: 1, status: 'SAFE' };
  if (dist <= 150 && !limitHigh) return { rule: 2, status: 'NOISE' };
  return { rule: 3, status: 'TRAIN' };
}

function nextSenderPayload() {
  tick += 1;
  distance = Math.max(50, distance + (Math.random() > 0.7 ? -20 : 5));
  const limitSwitch = distance <= 120 && Math.random() > 0.6;
  const { rule, status } = evaluateRule(distance, limitSwitch);

  return {
    deviceId: SENDER_ID,
    deviceType: 'sender',
    distance: Math.round(distance),
    limitSwitch,
    rule,
    status,
    alarm: rule === 3,
    battery: 70 + Math.floor(Math.random() * 25),
    signal: 10 + Math.floor(Math.random() * 20),
    timestamp: Math.floor(Date.now() / 1000),
    latitude: -6.914744 + (Math.random() * 0.001),
    longitude: 107.60981 + (Math.random() * 0.001),
    speed: Math.round(Math.random() * 10),
  };
}

function publishJson(client, topic, payload) {
  return new Promise((resolve, reject) => {
    client.publish(topic, JSON.stringify(payload), { qos: 1 }, (err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}

const client = mqtt.connect(BROKER_URL, options);

client.on('connect', () => {
  console.log(`[simulate:mqtt] connected ${BROKER_URL}`);
  console.log(`[simulate:mqtt] sender=${SENDER_ID} receiver=${RECEIVER_ID}`);
  console.log(`[simulate:mqtt] telemetry every ${TELEMETRY_MS}ms, heartbeat every ${HEARTBEAT_MS}ms`);

  setInterval(async () => {
    try {
      const payload = nextSenderPayload();
      const topic = `tracksafe/sender/${SENDER_ID}`;
      await publishJson(client, topic, payload);
      console.log(
        `[simulate:mqtt] #${tick} sender | ${payload.status} rule=${payload.rule} ` +
        `dist=${payload.distance} limit=${payload.limitSwitch}`,
      );

      if (payload.rule !== lastRule) {
        lastRule = payload.rule;
        const alarmTopic = `tracksafe/alarm/${SENDER_ID}`;
        await publishJson(client, alarmTopic, {
          deviceId: SENDER_ID,
          status: payload.status,
          alarm: payload.alarm,
          rule: payload.rule,
          distance: payload.distance,
          battery: payload.battery,
          signal: payload.signal,
          timestamp: payload.timestamp,
        });
        console.log(`[simulate:mqtt] Rule Changed → alarm published rule=${payload.rule}`);
      }
    } catch (e) {
      console.error('[simulate:mqtt] sender publish failed:', e.message);
    }
  }, TELEMETRY_MS);

  setInterval(async () => {
    try {
      const hbTopic = `tracksafe/heartbeat/${SENDER_ID}`;
      await publishJson(client, hbTopic, {
        deviceId: SENDER_ID,
        battery: 80,
        signal: 18,
        timestamp: Math.floor(Date.now() / 1000),
      });
    } catch (e) {
      console.error('[simulate:mqtt] sender heartbeat failed:', e.message);
    }
  }, HEARTBEAT_MS);

  setInterval(async () => {
    try {
      const topic = `tracksafe/receiver/${RECEIVER_ID}`;
      await publishJson(client, topic, {
        deviceId: RECEIVER_ID,
        deviceType: 'receiver',
        battery: 75 + Math.floor(Math.random() * 20),
        signal: 12 + Math.floor(Math.random() * 15),
        online: true,
        timestamp: Math.floor(Date.now() / 1000),
      });
      console.log(`[simulate:mqtt] receiver heartbeat ${RECEIVER_ID}`);
    } catch (e) {
      console.error('[simulate:mqtt] receiver publish failed:', e.message);
    }
  }, HEARTBEAT_MS);
});

client.on('error', (err) => {
  console.error('[simulate:mqtt] error:', err.message);
});

client.on('reconnect', () => {
  console.log('[simulate:mqtt] Reconnect MQTT');
});

client.on('close', () => {
  console.log('[simulate:mqtt] MQTT Disconnected');
});
