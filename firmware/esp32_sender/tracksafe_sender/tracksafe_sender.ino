/**
 * TrackSafe V2 — Sender ESP32 (MQTT / HiveMQ)
 *
 * Rule 1: TOF >150cm + Limit LOW  → SAFE   (LED hijau, sirine OFF)
 * Rule 2: TOF <=150cm + Limit LOW → NOISE  (LED kuning, sirine OFF)
 * Rule 3: TOF <=150cm + Limit HIGH → TRAIN (LED merah, sirine ON)
 *
 * Publish:
 *   tracksafe/sender/{deviceId}     — telemetry setiap 1 detik
 *   tracksafe/heartbeat/{deviceId}  — setiap 10 detik
 *   tracksafe/alarm/{deviceId}      — hanya saat rule berubah
 *
 * Dependencies (Arduino Library Manager):
 *   PubSubClient, ArduinoJson, WiFi (built-in ESP32)
 */

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>

// ─── Konfigurasi perangkat ───────────────────────────────────────────────────
#ifndef DEVICE_ID
#define DEVICE_ID "sender01"
#endif

#ifndef PAIRED_RECEIVER
#define PAIRED_RECEIVER "receiver01"
#endif

// WiFi (development) — produksi bisa diganti TinyGSM/GPRS
#ifndef WIFI_SSID
#define WIFI_SSID "YOUR_WIFI_SSID"
#endif
#ifndef WIFI_PASS
#define WIFI_PASS "YOUR_WIFI_PASSWORD"
#endif

// HiveMQ — public broker (1883) atau HiveMQ Cloud (8883 + TLS)
#ifndef MQTT_HOST
#define MQTT_HOST "broker.hivemq.com"
#endif
#ifndef MQTT_PORT
#define MQTT_PORT 1883
#endif
#ifndef MQTT_USER
#define MQTT_USER ""
#endif
#ifndef MQTT_PASS
#define MQTT_PASS ""
#endif

// Pin hardware (sesuaikan board LilyGO)
#define PIN_TOF_TRIG 18
#define PIN_TOF_ECHO 19
#define PIN_LIMIT    21
#define PIN_LED_G    25
#define PIN_LED_Y    26
#define PIN_LED_R    27
#define PIN_SIREN    33

#define TELEMETRY_INTERVAL_MS  1000
#define HEARTBEAT_INTERVAL_MS  10000
#define WDT_TIMEOUT_SEC        30
#define QUEUE_MAX              32

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

String topicSender;
String topicHeartbeat;
String topicAlarm;

unsigned long lastTelemetryMs = 0;
unsigned long lastHeartbeatMs = 0;
int lastRule = 0;
int batteryPct = 85;
int signalPct = 70;

struct QueuedMsg {
  String topic;
  String payload;
};

QueuedMsg publishQueue[QUEUE_MAX];
int queueHead = 0;
int queueTail = 0;

// ─── Logging helpers ─────────────────────────────────────────────────────────
#define LOG_I(msg) Serial.printf("[INFO] %s\n", msg)
#define LOG_E(msg) Serial.printf("[ERROR] %s\n", msg)

void logEvent(const char* event) {
  Serial.printf("[%lu] %s\n", millis(), event);
}

// ─── Offline queue ───────────────────────────────────────────────────────────
bool queuePush(const String& topic, const String& payload) {
  int next = (queueTail + 1) % QUEUE_MAX;
  if (next == queueHead) {
    LOG_E("Publish queue full — dropping oldest");
    queueHead = (queueHead + 1) % QUEUE_MAX;
  }
  publishQueue[queueTail] = { topic, payload };
  queueTail = next;
  return true;
}

void replayQueue() {
  if (!mqtt.connected()) return;
  while (queueHead != queueTail) {
    const QueuedMsg& m = publishQueue[queueHead];
    if (!mqtt.publish(m.topic.c_str(), m.payload.c_str(), false)) {
      LOG_E("Publish Failed — queue replay stopped");
      return;
    }
    logEvent("Publish Success — replayed queued message");
    queueHead = (queueHead + 1) % QUEUE_MAX;
  }
}

bool mqttPublish(const String& topic, const String& payload, bool retain = false) {
  if (mqtt.connected() && mqtt.publish(topic.c_str(), payload.c_str(), retain)) {
    logEvent("Publish Success");
    return true;
  }
  queuePush(topic, payload);
  LOG_E("Publish Failed — queued for replay");
  return false;
}

// ─── Sensor ──────────────────────────────────────────────────────────────────
int readTofCm() {
  digitalWrite(PIN_TOF_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TOF_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TOF_TRIG, LOW);
  long duration = pulseIn(PIN_TOF_ECHO, HIGH, 30000);
  if (duration <= 0) {
    logEvent("Sensor Error — TOF timeout");
    return -1;
  }
  return (int)(duration * 0.034 / 2);
}

bool readLimitSwitchHigh() {
  return digitalRead(PIN_LIMIT) == HIGH;
}

struct RuleResult {
  int rule;
  const char* status;
  bool alarm;
};

RuleResult evaluateRule(int distanceCm, bool limitHigh) {
  RuleResult r;
  if (distanceCm < 0) {
    r = { 2, "NOISE", false };
    return r;
  }
  if (distanceCm > 150 && !limitHigh) {
    r = { 1, "SAFE", false };
  } else if (distanceCm <= 150 && !limitHigh) {
    r = { 2, "NOISE", false };
  } else {
    r = { 3, "TRAIN", true };
  }
  return r;
}

void applyOutputs(RuleResult r) {
  digitalWrite(PIN_LED_G, r.rule == 1 ? HIGH : LOW);
  digitalWrite(PIN_LED_Y, r.rule == 2 ? HIGH : LOW);
  digitalWrite(PIN_LED_R, r.rule == 3 ? HIGH : LOW);
  digitalWrite(PIN_SIREN, r.alarm ? HIGH : LOW);
}

// ─── Network ─────────────────────────────────────────────────────────────────
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  logEvent("Reconnect GSM/WiFi — connecting WiFi");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    esp_task_wdt_reset();
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[INFO] WiFi connected IP=%s\n", WiFi.localIP().toString().c_str());
    signalPct = min(100, max(0, 2 * (WiFi.RSSI() + 100)));
  } else {
    LOG_E("WiFi connect failed");
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Sender tidak subscribe telemetry; pairing via backend REST API
}

void connectMqtt() {
  if (mqtt.connected()) return;
  logEvent("Reconnect MQTT — connecting broker");

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(1024);

  String clientId = String("tracksafe-sender-") + DEVICE_ID;
  bool ok;
  if (strlen(MQTT_USER) > 0) {
    ok = mqtt.connect(clientId.c_str(), MQTT_USER, MQTT_PASS);
  } else {
    ok = mqtt.connect(clientId.c_str());
  }

  if (ok) {
    logEvent("MQTT Connected");
    replayQueue();
  } else {
    Serial.printf("[ERROR] MQTT connect failed rc=%d\n", mqtt.state());
  }
}

String buildTelemetryJson(int distance, bool limitHigh, RuleResult rule) {
  StaticJsonDocument<512> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["deviceType"] = "sender";
  doc["distance"] = distance;
  doc["limitSwitch"] = limitHigh;
  doc["rule"] = rule.rule;
  doc["status"] = rule.status;
  doc["alarm"] = rule.alarm;
  doc["battery"] = batteryPct;
  doc["signal"] = signalPct;
  doc["timestamp"] = (uint32_t)(millis() / 1000);

  String out;
  serializeJson(doc, out);
  return out;
}

void publishTelemetry(int distance, bool limitHigh, RuleResult rule) {
  String payload = buildTelemetryJson(distance, limitHigh, rule);
  mqttPublish(topicSender, payload);

  if (rule.rule != lastRule && lastRule != 0) {
    StaticJsonDocument<256> doc;
    doc["deviceId"] = DEVICE_ID;
    doc["status"] = rule.status;
    doc["alarm"] = rule.alarm;
    doc["rule"] = rule.rule;
    doc["distance"] = distance;
    doc["battery"] = batteryPct;
    doc["signal"] = signalPct;
    doc["timestamp"] = (uint32_t)(millis() / 1000);
    String alarmPayload;
    serializeJson(doc, alarmPayload);
    mqttPublish(topicAlarm, alarmPayload);
    Serial.printf("[INFO] Rule Changed %d → %d (%s)\n", lastRule, rule.rule, rule.status);
  }
  lastRule = rule.rule;
}

void publishHeartbeat() {
  StaticJsonDocument<256> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["battery"] = batteryPct;
  doc["signal"] = signalPct;
  doc["timestamp"] = (uint32_t)(millis() / 1000);
  String payload;
  serializeJson(doc, payload);
  mqttPublish(topicHeartbeat, payload);
  logEvent("Heartbeat Sent");
}

// ─── Setup / Loop ────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(PIN_TOF_TRIG, OUTPUT);
  pinMode(PIN_TOF_ECHO, INPUT);
  pinMode(PIN_LIMIT, INPUT_PULLUP);
  pinMode(PIN_LED_G, OUTPUT);
  pinMode(PIN_LED_Y, OUTPUT);
  pinMode(PIN_LED_R, OUTPUT);
  pinMode(PIN_SIREN, OUTPUT);

  topicSender = String("tracksafe/sender/") + DEVICE_ID;
  topicHeartbeat = String("tracksafe/heartbeat/") + DEVICE_ID;
  topicAlarm = String("tracksafe/alarm/") + DEVICE_ID;

  esp_task_wdt_init(WDT_TIMEOUT_SEC, true);
  esp_task_wdt_add(NULL);

  connectWiFi();
  connectMqtt();

  LOG_I("TrackSafe Sender V2 — MQTT mode (no HTTP/Firebase)");
}

void loop() {
  esp_task_wdt_reset();

  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }
  if (!mqtt.connected()) {
    logEvent("MQTT Disconnected");
    connectMqtt();
  }
  mqtt.loop();

  unsigned long now = millis();

  if (now - lastTelemetryMs >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryMs = now;
    int distance = readTofCm();
    bool limitHigh = readLimitSwitchHigh();
    RuleResult rule = evaluateRule(distance, limitHigh);
    applyOutputs(rule);
    publishTelemetry(distance, limitHigh, rule);
    Serial.printf("[INFO] Battery=%d Signal=%d Distance=%d Rule=%d\n",
                  batteryPct, signalPct, distance, rule.rule);
  }

  if (now - lastHeartbeatMs >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatMs = now;
    publishHeartbeat();
  }
}
