/**
 * MQTT topic + payload parsing and validation.
 */

const mqttConfig = require('../config/mqtt.config');

/**
 * Parse topic {MQTT_TOPIC_ROOT}/{kind}/{deviceId}
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
  if (parts.length < 3 || parts[0] !== root) {
    return { ok: false, error: `Invalid topic root: ${raw}` };
  }

  const kind = parts[1];
  const deviceId = parts.slice(2).join('/');

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
    case 'receiver':
    case 'heartbeat':
      break;
    case 'alarm':
      if (payload.alarm === undefined && payload.status == null) {
        return { ok: false, error: 'alarm requires alarm or status field' };
      }
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
