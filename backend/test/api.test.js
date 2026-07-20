/**
 * API validation tests (no live Firebase required for unit checks).
 */

const assert = require('assert');
const deviceStatusEngine = require('../services/device-status.engine');
const telemetryService = require('../services/telemetry.service');

function testDeviceStatusEngine() {
  const now = Date.now();
  assert.strictEqual(
    deviceStatusEngine.resolveLinkStatus(null, { exists: false }),
    'OFF',
  );

  const waiting = deviceStatusEngine.resolveLinkStatus({}, { exists: true, nowMs: now });
  assert.strictEqual(waiting, 'WAITING');

  const online = deviceStatusEngine.resolveLinkStatus({
    battery: 90,
    signal: 20,
    latitude: -6.9,
    longitude: 107.6,
    lastUpdate: now - 1000,
  }, { exists: true, nowMs: now });
  assert.strictEqual(online, 'ONLINE');

  const off = deviceStatusEngine.resolveLinkStatus({
    battery: 90,
    signal: 20,
    latitude: -6.9,
    longitude: 107.6,
    lastUpdate: now - 60_000,
  }, { exists: true, nowMs: now });
  assert.strictEqual(off, 'OFF');
}

function testTelemetryValidation() {
  const bad = telemetryService.validateGpsFields({
    latitude: 'x',
    longitude: 1,
    speed: 0,
    timestamp: 1,
  });
  assert.strictEqual(bad.ok, false);

  const good = telemetryService.validateGpsFields({
    latitude: -6.9,
    longitude: 107.6,
    speed: 1,
    timestamp: 1720000000,
  });
  assert.strictEqual(good.ok, true);
  assert.strictEqual(good.latitude, -6.9);
}

function testStatusNormalization() {
  assert.strictEqual(telemetryService.normalizeStatus('danger'), 'DANGER');
  assert.strictEqual(telemetryService.normalizeStatus('SAFE'), 'NORMAL');
  assert.strictEqual(telemetryService.normalizeStatus('TRAIN'), 'DANGER');
  assert.strictEqual(telemetryService.normalizeStatus('invalid'), null);
}

function testMqttRuleStatus() {
  assert.strictEqual(telemetryService.normalizeRuleStatus(1), 'NORMAL');
  assert.strictEqual(telemetryService.normalizeRuleStatus(2), 'NOISE');
  assert.strictEqual(telemetryService.normalizeRuleStatus(3), 'DANGER');
  assert.strictEqual(
    telemetryService.resolveMqttStatus({ status: 'TRAIN' }),
    'DANGER',
  );
  assert.strictEqual(
    telemetryService.resolveMqttStatus({ rule: 2 }),
    'NOISE',
  );
}

function testMqttTopicParse() {
  const { parseTopic, parsePayload, validatePayload } = require('../utils/mqttParser');

  const parsed = parseTopic('tracksafe/sender/sender01');
  assert.strictEqual(parsed.ok, true);
  assert.strictEqual(parsed.kind, 'sender');
  assert.strictEqual(parsed.deviceId, 'sender01');

  const badTopic = parseTopic('invalid/topic');
  assert.strictEqual(badTopic.ok, false);

  const payload = parsePayload(Buffer.from('{"deviceId":"s1","status":"SAFE"}'));
  assert.strictEqual(payload.ok, true);

  const badJson = parsePayload(Buffer.from('not-json'));
  assert.strictEqual(badJson.ok, false);

  const valid = validatePayload('sender', { status: 'SAFE' });
  assert.strictEqual(valid.ok, true);
}

function testMqttHealthLabel() {
  const mqttService = require('../services/mqtt.service');
  const label = mqttService.getMqttHealthLabel();
  assert.ok(['connected', 'disconnected', 'disabled'].includes(label));
}

testDeviceStatusEngine();
testTelemetryValidation();
testStatusNormalization();
testMqttRuleStatus();
testMqttTopicParse();
testMqttHealthLabel();

console.log('[test] all API unit checks passed');
