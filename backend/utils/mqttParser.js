/**
 * MQTT topic + payload parsing and validation.
 *
 * Supports TWO topic formats:
 *   Old: {root}/{kind}/{deviceId}        e.g. tracksafe/sender/sender01
 *   New: {root}/device/{deviceId}/{kind}  e.g. tracksafe/device/sender01/telemetry
 */

const mqttConfig = require('../config/mqtt.config');

/**
 * Parse topic — supports both old and new ESP32 topic formats.
 *
 * Old format: {MQTT_TOPIC_ROOT}/{kind}/{deviceId}
 *   e.g. tracksafe/sender/sender01
 *   → kind=sender, deviceId=sender01
 *
 * New format: {MQTT_TOPIC_ROOT}/device/{deviceId}/{kind}
 *   e.g. tracksafe/device/sender01/telemetry
 *   → kind=telemetry, deviceId=sender01
 *
 * @param {string} topic
 * @returns {{ ok: true, kind: string, deviceId: string } | { ok: false, error: string }}
 */
function parseTopic(topic) {
  const raw = String(topic || '').trim();
  if (!raw) {
    return { ok: false, error: 'Empty topic' };
  }

  const root = mqttConfig.getTopicRoot();
  const parts = raw.split('/').filter(Boolean);

  // Minimum: root + kind + deviceId (3 parts) or root + device + deviceId + kind (4 parts)
  if (parts.length < 3 || parts[0] !== root) {
    return { ok: false, error: `Invalid topic root: ${raw}` };
  }

  let kind, deviceId;

  // Detect format: if parts[1] === 'device', it's the new format
  if (parts[1] === 'device' && parts.length >= 4) {
    // New format: tracksafe/device/{deviceId}/{kind}
    deviceId = parts[2];
    kind = parts.slice(3).join('/');
  } else {
    // Old format: tracksafe/{kind}/{deviceId}
    kind = parts[1];
    deviceId = parts.slice(2).join('/');
  }

  if (!mqttConfig.VALID_KINDS.has(kind)) {
    return { ok: false, error: `Unknown topic kind: ${kind}` };
  }

  if (!deviceId || !deviceId.trim()) {
    return { ok: false, error: 'Missing deviceId in topic' };
  }

  return { ok: true, kind, deviceId };
}

/**
 * @param {Buffer|string} message
 * @returns {{ ok: true, payload: object } | { ok: false, error: string }}
 */
function parsePayload(message) {
  const raw = message.toString();
  if (!raw.trim()) {
    return { ok: false, error: 'Empty payload' };
  }

  try {
    const payload = JSON.parse(raw);
    if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
      return { ok: false, error: 'Payload must be a JSON object' };
    }
    return { ok: true, payload };
  } catch (_e) {
    return { ok: false, error: 'Invalid JSON payload' };
  }
}

/**
 * Validate payload fields per topic kind.
 * @param {string} kind
 * @param {object} payload
 * @returns {{ ok: true } | { ok: false, error: string }}
 */
function validatePayload(kind, payload) {
  if (!payload || typeof payload !== 'object') {
    return { ok: false, error: 'Payload is not an object' };
  }

  switch (kind) {
    case 'sender':
      if (payload.deviceId != null && typeof payload.deviceId !== 'string') {
        return { ok: false, error: 'deviceId must be string' };
      }
      if (payload.status == null && payload.rule == null) {
        return { ok: false, error: 'sender requires status or rule' };
      }
      break;

    case 'telemetry':
      // Telemetry: deviceId required, status or rule required
      if (payload.deviceId != null && typeof payload.deviceId !== 'string') {
        return { ok: false, error: 'deviceId must be string' };
      }
      if (payload.status == null && payload.rule == null) {
        return { ok: false, error: 'telemetry requires status or rule' };
      }
      break;

    case 'status':
      // Status: deviceId required, status or rule required
      if (payload.deviceId != null && typeof payload.deviceId !== 'string') {
        return { ok: false, error: 'deviceId must be string' };
      }
      if (payload.status == null && payload.rule == null) {
        return { ok: false, error: 'status requires status or rule' };
      }
      break;

    case 'receiver':
    case 'heartbeat':
      break;

    case 'alarm':
      if (payload.alarm === undefined && payload.status == null) {
        return { ok: false, error: 'alarm requires alarm or status field' };
      }
      break;

    case 'command':
      // Command: any payload is valid (deviceId optional)
      break;

    case 'config':
    case 'pairing':
      break;

    default:
      return { ok: false, error: `Unsupported kind: ${kind}` };
  }

  return { ok: true };
}

/** @deprecated use parseTopic — returns null on failure for backward compat */
function parseTopicLegacy(topic) {
  const result = parseTopic(topic);
  if (!result.ok) return null;
  return { kind: result.kind, deviceId: result.deviceId };
}

module.exports = {
  parseTopic,
  parsePayload,
  validatePayload,
  parseTopicLegacy,
};