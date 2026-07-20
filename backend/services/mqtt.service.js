/**
 * MQTT service — HiveMQ subscriber for TrackSafe IoT devices.
 * Routes incoming messages to existing services (no duplicate business logic).
 */

const mqtt = require('mqtt');
const { getDatabase, initFirebase } = require('../config/firebase');
const mqttConfig = require('../config/mqtt.config');
const { parseTopic, parsePayload, validatePayload } = require('../utils/mqttParser');
const { withFirebaseRetry } = require('../utils/firebaseRetry');
const deviceStatusEngine = require('./device-status.engine');
const telemetryService = require('./telemetry.service');
const deviceService = require('./device.service');
const alarmService = require('./alarm.service');
const historyService = require('./history.service');
const logger = require('../config/logger');

/** @type {import('mqtt').MqttClient|null} */
let client = null;
let reconnectTimer = null;
let heartbeatTimer = null;
let started = false;

const state = {
  connected: false,
  lastConnectedAt: null,
  lastDisconnectedAt: null,
  lastMessageAt: null,
  messagesProcessed: 0,
  lastError: null,
  broker: null,
};

async function handleSender(deviceId, payload) {
  const body = { ...payload, deviceId: payload.deviceId || deviceId };
  logger.debug(
    `[mqtt] sender ${body.deviceId} | status=${body.status} rule=${body.rule} ` +
    `dist=${body.distance} bat=${body.battery} sig=${body.signal}`,
  );
  await withFirebaseRetry(
    () => telemetryService.saveMqttSenderData(body),
    { label: `sender/${body.deviceId}` },
  );
}

async function ensureHeartbeat(body, deviceType) {
  await withFirebaseRetry(async () => {
    try {
      await deviceService.saveHeartbeat(body);
    } catch (error) {
      if (error.statusCode === 404) {
        await deviceService.registerDevice({
          deviceId: body.deviceId,
          deviceType,
        });
        await deviceService.saveHeartbeat(body);
        return;
      }
      throw error;
    }
  }, { label: `heartbeat/${body.deviceId}` });
}

async function handleReceiver(deviceId, payload) {
  const body = {
    ...payload,
    deviceId: payload.deviceId || deviceId,
    online: payload.online !== false,
  };
  logger.debug(`[mqtt] receiver ${body.deviceId} | bat=${body.battery} sig=${body.signal}`);
  await ensureHeartbeat(body, 'receiver');
  logger.info(`[mqtt] Receiver Online — heartbeat ${body.deviceId}`);
}

async function handleHeartbeat(deviceId, payload) {
  const body = { ...payload, deviceId: payload.deviceId || deviceId };
  logger.debug(`[mqtt] heartbeat ${body.deviceId}`);
  const deviceType = String(body.deviceType || '').toLowerCase() === 'receiver'
    ? 'receiver'
    : 'sender';
  await ensureHeartbeat(body, deviceType);
  logger.info(`[mqtt] Heartbeat Sent — processed ${body.deviceId}`);
}

async function handleAlarm(deviceId, payload) {
  logger.info(`[mqtt] alarm ${deviceId} | status=${payload.status} alarm=${payload.alarm}`);
  await withFirebaseRetry(
    () => alarmService.processAlarmMessage(deviceId, payload),
    { label: `alarm/${deviceId}` },
  );
}

async function handleConfig(deviceId, payload) {
  logger.info(`[mqtt] config ${deviceId}`);
  const db = getDatabase();
  await withFirebaseRetry(
    () => db.ref(`devices/${deviceId}/config`).set({
      ...payload,
      deviceId,
      updatedAt: Date.now(),
    }),
    { label: `config/${deviceId}` },
  );
}

async function handlePairing(deviceId, payload) {
  logger.info(`[mqtt] pairing ${deviceId}`);
  const action = String(payload.action || '').toLowerCase();

  if (action === 'pair' && payload.senderId && payload.receiverId) {
    await withFirebaseRetry(
      () => deviceService.pairDevices({
        senderId: payload.senderId,
        receiverId: payload.receiverId,
      }),
      { label: 'pairing/pair' },
    );
    return;
  }

  if (action === 'unpair') {
    await withFirebaseRetry(
      () => deviceService.unpairDevices({
        senderId: payload.senderId || deviceId,
        receiverId: payload.receiverId,
      }),
      { label: 'pairing/unpair' },
    );
    return;
  }

  const db = getDatabase();
  await withFirebaseRetry(
    () => db.ref(`devices/${deviceId}/mqttPairing`).set({
      ...payload,
      deviceId,
      updatedAt: Date.now(),
    }),
    { label: `pairing/${deviceId}` },
  );
}

async function routeMessage(topic, payload, kind, deviceId) {
  switch (kind) {
    case 'sender':
      await handleSender(deviceId, payload);
      break;
    case 'receiver':
      await handleReceiver(deviceId, payload);
      break;
    case 'heartbeat':
      await handleHeartbeat(deviceId, payload);
      break;
    case 'alarm':
      await handleAlarm(deviceId, payload);
      break;
    case 'config':
      await handleConfig(deviceId, payload);
      break;
    case 'pairing':
      await handlePairing(deviceId, payload);
      break;
    default:
      logger.debug(`[mqtt] unhandled kind=${kind} topic=${topic}`);
  }
}

async function onMessage(topic, message) {
  state.lastMessageAt = Date.now();
  state.messagesProcessed += 1;
  logger.info(`[mqtt] MQTT Message Received — topic=${topic}`);

  const topicResult = parseTopic(topic);
  if (!topicResult.ok) {
    logger.error(`[mqtt] Topic validation failed: ${topicResult.error}`);
    return;
  }

  const payloadResult = parsePayload(message);
  if (!payloadResult.ok) {
    logger.error(`[mqtt] JSON validation failed on ${topic}: ${payloadResult.error}`);
    return;
  }

  const validation = validatePayload(topicResult.kind, payloadResult.payload);
  if (!validation.ok) {
    logger.error(`[mqtt] Payload validation failed on ${topic}: ${validation.error}`);
    return;
  }

  try {
    await routeMessage(
      topic,
      payloadResult.payload,
      topicResult.kind,
      topicResult.deviceId,
    );
  } catch (error) {
    state.lastError = error.message;
    logger.error(`[mqtt] message handler failed — topic=${topic}:`, error.message);
  }
}

async function runHeartbeatMonitor() {
  try {
    const db = getDatabase();
    const snap = await db.ref('devices').once('value');
    const val = snap.val();
    if (!val || typeof val !== 'object') return;

    const nowMs = Date.now();
    const threshold = deviceStatusEngine.OFFLINE_THRESHOLD_MS;
    const updates = [];

    Object.keys(val).forEach((deviceId) => {
      const device = val[deviceId];
      if (!device || typeof device !== 'object') return;

      const lastMs = deviceStatusEngine.getLastHeartbeatMs(device);
      if (lastMs <= 0) return;

      const ageMs = nowMs - lastMs;
      const isOnline = device.online === true;
      const deviceType = deviceStatusEngine.resolveDeviceType(deviceId, device);

      if (ageMs > threshold && isOnline) {
        updates.push(async () => {
          await withFirebaseRetry(
            () => db.ref(`devices/${deviceId}`).update({
              online: false,
              linkStatus: deviceStatusEngine.LINK_STATUS.OFF,
            }),
            { label: `offline/${deviceId}` },
          );

          const eventType = deviceType === 'receiver'
            ? historyService.EVENT_TYPES.RECEIVER_DISCONNECT
            : historyService.EVENT_TYPES.OFFLINE;

          await withFirebaseRetry(
            () => historyService.writeHistory({
              eventType,
              deviceId,
              status: device.status || 'NORMAL',
              battery: device.battery,
              signal: device.signal,
              description: deviceType === 'receiver'
                ? `Receiver offline: ${deviceId}`
                : `Sender offline: ${deviceId}`,
            }),
            { label: `history/offline/${deviceId}` },
          );

          if (deviceType === 'receiver') {
            logger.info(`[mqtt] Receiver Offline — ${deviceId}`);
          } else {
            logger.info(`[mqtt] Sender offline detection — ${deviceId}`);
          }
        });
      }
    });

    await Promise.all(updates.map((fn) => fn()));
  } catch (error) {
    logger.error('[mqtt] heartbeat monitor error:', error.message);
  }
}

function scheduleReconnect() {
  if (reconnectTimer || !started) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    if (!state.connected && started) {
      logger.info('[mqtt] MQTT Reconnecting — manual retry');
      connectInternal();
    }
  }, mqttConfig.RECONNECT_MS);
}

function connectInternal() {
  if (client) {
    try { client.end(true); } catch (_e) { /* ignore */ }
    client = null;
  }

  const url = mqttConfig.buildBrokerUrl();
  state.broker = url;
  const options = mqttConfig.buildClientOptions();

  logger.info(`[mqtt] connecting to ${url} clientId=${options.clientId}`);

  client = mqtt.connect(url, options);

  client.on('connect', () => {
    state.connected = true;
    state.lastConnectedAt = Date.now();
    state.lastError = null;
    logger.info('[mqtt] MQTT Connected');

    const pattern = mqttConfig.getSubscribePattern();
    const qos = mqttConfig.getQos();
    client.subscribe(pattern, { qos }, (err) => {
      if (err) {
        logger.error('[mqtt] subscribe failed:', err.message);
        return;
      }
      logger.info(`[mqtt] subscribed ${pattern} qos=${qos}`);
    });

    telemetryService.touchBackendHeartbeat().catch((e) => {
      logger.error('[mqtt] backend heartbeat touch failed:', e.message);
    });
  });

  client.on('reconnect', () => {
    logger.info('[mqtt] MQTT Reconnecting — broker reconnect event');
  });

  client.on('close', () => {
    state.connected = false;
    state.lastDisconnectedAt = Date.now();
    logger.info('[mqtt] MQTT Disconnected');
    scheduleReconnect();
  });

  client.on('error', (err) => {
    state.lastError = err.message;
    logger.error('[mqtt] MQTT Error:', err.message);
  });

  client.on('message', (topic, message) => {
    onMessage(topic, message);
  });
}

function startHeartbeatMonitor() {
  if (heartbeatTimer) return;
  heartbeatTimer = setInterval(() => {
    runHeartbeatMonitor();
  }, mqttConfig.HEARTBEAT_MONITOR_MS);
}

function stopHeartbeatMonitor() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

function startMqtt() {
  if (!mqttConfig.isEnabled()) {
    logger.info('[mqtt] MQTT disabled (MQTT_ENABLED=false)');
    return { started: false, enabled: false };
  }

  if (started) {
    return { started: true, enabled: true, alreadyRunning: true };
  }

  started = true;

  const hostConfigured = String(process.env.MQTT_HOST || '').trim();
  if (!hostConfigured) {
    logger.info(
      '[mqtt] MQTT_HOST kosong — memakai fallback broker.hivemq.com:1883. ' +
      'Isi MQTT_HOST / USERNAME / PASSWORD di .env atau Railway Variables untuk HiveMQ Cloud.',
    );
  }

  try {
    initFirebase();
  } catch (error) {
    logger.error('[mqtt] Firebase init failed:', error.message);
  }

  connectInternal();
  startHeartbeatMonitor();

  withFirebaseRetry(
    () => historyService.writeHistory({
      eventType: historyService.EVENT_TYPES.BACKEND_RESTART,
      deviceId: 'backend',
      status: 'NORMAL',
      description: 'MQTT subscriber started',
    }),
    { label: 'backend_restart' },
  ).catch((e) => logger.error('[mqtt] history write failed:', e.message));

  return { started: true, enabled: true };
}

function stopMqtt() {
  started = false;
  stopHeartbeatMonitor();

  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  if (client) {
    try { client.end(true); } catch (_e) { /* ignore */ }
    client = null;
  }

  state.connected = false;
  logger.info('[mqtt] MQTT subscriber stopped');
}

function getMqttStatus() {
  return {
    enabled: mqttConfig.isEnabled(),
    connected: state.connected,
    broker: state.broker,
    subscribePattern: mqttConfig.getSubscribePattern(),
    qos: mqttConfig.getQos(),
    tls: mqttConfig.useTls(),
    lastConnectedAt: state.lastConnectedAt,
    lastDisconnectedAt: state.lastDisconnectedAt,
    lastMessageAt: state.lastMessageAt,
    messagesProcessed: state.messagesProcessed,
    lastError: state.lastError,
  };
}

function getMqttHealthLabel() {
  const status = getMqttStatus();
  if (!status.enabled) return 'disabled';
  return status.connected ? 'connected' : 'disconnected';
}

module.exports = {
  startMqtt,
  stopMqtt,
  getMqttStatus,
  getMqttHealthLabel,
  isEnabled: mqttConfig.isEnabled,
  /** @internal testing */
  _routeMessage: routeMessage,
};
