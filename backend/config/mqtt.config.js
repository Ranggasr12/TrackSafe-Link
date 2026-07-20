/**
 * MQTT configuration — HiveMQ Cloud / public broker.
 * Semua nilai dari process.env (tidak hardcode secrets / host production).
 */

function envString(name, fallback = '') {
  const v = process.env[name];
  if (v === undefined || v === null || String(v).trim() === '') {
    return fallback;
  }
  return String(v).trim();
}

function envBool(name, fallback = false) {
  const raw = process.env[name];
  if (raw === undefined || raw === null || String(raw).trim() === '') {
    return fallback;
  }
  const s = String(raw).toLowerCase().trim();
  if (s === 'true' || s === '1' || s === 'yes') return true;
  if (s === 'false' || s === '0' || s === 'no') return false;
  return fallback;
}

function envInt(name, fallback) {
  const n = Number(process.env[name]);
  return Number.isFinite(n) ? n : fallback;
}

function isEnabled() {
  return envBool('MQTT_ENABLED', true);
}

function getTopicRoot() {
  return envString('MQTT_TOPIC_ROOT', 'tracksafe');
}

function getQos() {
  const qos = envInt('MQTT_QOS', 1);
  return qos === 0 || qos === 1 || qos === 2 ? qos : 1;
}

function getSubscribePattern() {
  return `${getTopicRoot()}/#`;
}

function useTls() {
  const hostConfigured = Boolean(envString('MQTT_HOST'));
  const port = envInt('MQTT_PORT', hostConfigured ? 8883 : 1883);
  if (port === 8883) return true;
  if (port === 1883 && !hostConfigured) return false;
  return envBool('MQTT_TLS', hostConfigured);
}

function buildBrokerUrl() {
  const hostConfigured = envString('MQTT_HOST');
  const host = hostConfigured || 'broker.hivemq.com';

  // Tanpa MQTT_HOST: fallback HiveMQ Public (1883, no TLS) untuk uji lokal.
  // Dengan MQTT_HOST (HiveMQ Cloud): pakai PORT/TLS dari ENV (default 8883 + TLS).
  let port;
  let tls;
  if (hostConfigured) {
    port = envInt('MQTT_PORT', 8883);
    tls = useTls();
  } else {
    port = 1883;
    tls = false;
  }

  const protocol = tls ? 'mqtts' : 'mqtt';
  return `${protocol}://${host}:${port}`;
}

function buildClientOptions() {
  const clientId = envString(
    'MQTT_CLIENT_ID',
    `tracksafe-backend-${Math.random().toString(16).slice(2, 10)}`,
  );

  const options = {
    clientId,
    clean: true,
    reconnectPeriod: envInt('MQTT_RECONNECT_MS', 5000),
    connectTimeout: envInt('MQTT_CONNECT_TIMEOUT_MS', 30_000),
    keepalive: envInt('MQTT_KEEPALIVE', 60),
  };

  const username = envString('MQTT_USERNAME');
  const password = envString('MQTT_PASSWORD');
  if (username) options.username = username;
  if (password) options.password = password;

  if (useTls()) {
    options.rejectUnauthorized = envBool('MQTT_TLS_REJECT_UNAUTHORIZED', true);
  }

  return options;
}

const VALID_KINDS = new Set([
  'sender',
  'receiver',
  'alarm',
  'heartbeat',
  'config',
  'pairing',
]);

/** Lazy getters — baca ENV saat runtime (setelah dotenv.load). */
module.exports = {
  get TOPIC_ROOT() {
    return getTopicRoot();
  },
  get SUBSCRIBE_PATTERN() {
    return getSubscribePattern();
  },
  get RECONNECT_MS() {
    return envInt('MQTT_RECONNECT_MS', 5000);
  },
  get HEARTBEAT_MONITOR_MS() {
    return envInt('MQTT_HEARTBEAT_MONITOR_MS', 30_000);
  },
  get QOS() {
    return getQos();
  },
  VALID_KINDS,
  isEnabled,
  getTopicRoot,
  getQos,
  getSubscribePattern,
  useTls,
  buildBrokerUrl,
  buildClientOptions,
};
