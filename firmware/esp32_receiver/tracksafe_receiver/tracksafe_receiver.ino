/**
 * TrackSafe V2 — Receiver ESP32 (MQTT / HiveMQ)
 *
 * Subscribe: tracksafe/sender/{pairedSender}
 * Publish:   tracksafe/receiver/{deviceId} setiap 10 detik
 *
 * SAFE  → LED hijau, sirine OFF
 * NOISE → LED kuning, sirine OFF
 * TRAIN → LED merah, sirine ON
 *
 * Pairing: backend Firebase pairings/ adalah source of truth.
 * Set PAIRED_SENDER sesuai sender yang dipairing via Flutter/API.
 */

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>

#ifndef DEVICE_ID
#define DEVICE_ID "receiver01"
#endif

#ifndef PAIRED_SENDER
#define PAIRED_SENDER "sender01"
#endif

#ifndef WIFI_SSID
#define WIFI_SSID "YOUR_WIFI_SSID"
#endif
#ifndef WIFI_PASS
#define WIFI_PASS "YOUR_WIFI_PASSWORD"
#endif

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

#define PIN_LED_G    25
#define PIN_LED_Y    26
#define PIN_LED_R    27
#define PIN_SIREN    33

#define RECEIVER_PUBLISH_MS 10000
#define WDT_TIMEOUT_SEC     30
#define QUEUE_MAX           16

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

String topicSubscribe;
String topicPublish;
String currentStatus = "SAFE";

unsigned long lastPublishMs = 0;
int batteryPct = 80;
int signalPct = 65;

struct QueuedMsg { String topic; String payload; };
QueuedMsg publishQueue[QUEUE_MAX];
int queueHead = 0;
int queueTail = 0;

void logEvent(const char* event) {
  Serial.printf("[%lu] %s\n", millis(), event);
}

bool queuePush(const String& topic, const String& payload) {
  int next = (queueTail + 1) % QUEUE_MAX;
  if (next == queueHead) queueHead = (queueHead + 1) % QUEUE_MAX;
  publishQueue[queueTail] = { topic, payload };
  queueTail = next;
  return true;
}

void replayQueue() {
  while (queueHead != queueTail && mqtt.connected()) {
    const QueuedMsg& m = publishQueue[queueHead];
    if (!mqtt.publish(m.topic.c_str(), m.payload.c_str())) return;
    queueHead = (queueHead + 1) % QUEUE_MAX;
  }
}

bool mqttPublish(const String& topic, const String& payload) {
  if (mqtt.connected() && mqtt.publish(topic.c_str(), payload.c_str())) {
    logEvent("Publish Success");
    return true;
  }
  queuePush(topic, payload);
  logEvent("Publish Failed — queued");
  return false;
}

void applyStatus(const String& status) {
  String s = status;
  s.toUpperCase();
  if (s == "NORMAL") s = "SAFE";

  bool safe = (s == "SAFE");
  bool noise = (s == "NOISE");
  bool train = (s == "TRAIN" || s == "DANGER");

  digitalWrite(PIN_LED_G, safe ? HIGH : LOW);
  digitalWrite(PIN_LED_Y, noise ? HIGH : LOW);
  digitalWrite(PIN_LED_R, train ? HIGH : LOW);
  digitalWrite(PIN_SIREN, train ? HIGH : LOW);

  if (currentStatus != s) {
    Serial.printf("[INFO] Rule Changed receiver output → %s\n", s.c_str());
    currentStatus = s;
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, payload, length);
  if (err) {
    logEvent("Sensor Error — invalid JSON from sender");
    return;
  }

  const char* status = doc["status"] | "SAFE";
  applyStatus(String(status));
  logEvent("Receiver Online — sender telemetry received");
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  logEvent("Reconnect GSM/WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int n = 0;
  while (WiFi.status() != WL_CONNECTED && n++ < 40) {
    delay(500);
    esp_task_wdt_reset();
  }
  if (WiFi.status() == WL_CONNECTED) {
    signalPct = min(100, max(0, 2 * (WiFi.RSSI() + 100)));
    Serial.printf("[INFO] WiFi IP=%s\n", WiFi.localIP().toString().c_str());
  }
}

void connectMqtt() {
  if (mqtt.connected()) return;
  logEvent("Reconnect MQTT");

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(1024);

  String clientId = String("tracksafe-receiver-") + DEVICE_ID;
  bool ok = strlen(MQTT_USER) > 0
    ? mqtt.connect(clientId.c_str(), MQTT_USER, MQTT_PASS)
    : mqtt.connect(clientId.c_str());

  if (ok) {
    logEvent("MQTT Connected");
    mqtt.subscribe(topicSubscribe.c_str(), 1);
    Serial.printf("[INFO] Subscribed %s\n", topicSubscribe.c_str());
    replayQueue();
  } else {
    Serial.printf("[ERROR] MQTT rc=%d\n", mqtt.state());
  }
}

void publishReceiverStatus() {
  StaticJsonDocument<256> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["deviceType"] = "receiver";
  doc["battery"] = batteryPct;
  doc["signal"] = signalPct;
  doc["online"] = true;
  doc["timestamp"] = (uint32_t)(millis() / 1000);

  String payload;
  serializeJson(doc, payload);
  mqttPublish(topicPublish, payload);
  logEvent("Heartbeat Sent");
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED_G, OUTPUT);
  pinMode(PIN_LED_Y, OUTPUT);
  pinMode(PIN_LED_R, OUTPUT);
  pinMode(PIN_SIREN, OUTPUT);

  topicSubscribe = String("tracksafe/sender/") + PAIRED_SENDER;
  topicPublish = String("tracksafe/receiver/") + DEVICE_ID;

  esp_task_wdt_init(WDT_TIMEOUT_SEC, true);
  esp_task_wdt_add(NULL);

  connectWiFi();
  connectMqtt();

  Serial.println("[INFO] TrackSafe Receiver V2 — MQTT mode");
}

void loop() {
  esp_task_wdt_reset();

  if (WiFi.status() != WL_CONNECTED) connectWiFi();
  if (!mqtt.connected()) {
    logEvent("MQTT Disconnected");
    connectMqtt();
  }
  mqtt.loop();

  unsigned long now = millis();
  if (now - lastPublishMs >= RECEIVER_PUBLISH_MS) {
    lastPublishMs = now;
    publishReceiverStatus();
    Serial.printf("[INFO] Battery=%d Signal=%d\n", batteryPct, signalPct);
  }
}
