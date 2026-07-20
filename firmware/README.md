# TrackSafe V2 — ESP32 Firmware (MQTT / HiveMQ)

Firmware Sender dan Receiver untuk migrasi HTTP → MQTT.

## Arsitektur

```
Sender ESP32  ──publish──►  HiveMQ  ◄──subscribe──  Backend Node.js
Receiver ESP32 ◄─subscribe─┘                    └──► Firebase ──► Flutter
```

ESP32 **tidak** mengakses Firebase atau HTTP POST.

## Dependencies (Arduino IDE / PlatformIO)

| Library | Purpose |
|---------|---------|
| PubSubClient | MQTT client |
| ArduinoJson | JSON payload |
| WiFi (ESP32) | Koneksi jaringan |

Produksi LilyGO + SIM800: tambahkan **TinyGSM** dan ganti `connectWiFi()` dengan GPRS.

## Konfigurasi

Edit `#define` di awal file `.ino`:

| Define | Default | Description |
|--------|---------|-------------|
| `DEVICE_ID` | sender01 / receiver01 | ID perangkat |
| `PAIRED_SENDER` | sender01 | Receiver: sender yang dipairing |
| `MQTT_HOST` | broker.hivemq.com | HiveMQ public atau Cloud |
| `MQTT_PORT` | 1883 | 8883 untuk TLS (HiveMQ Cloud) |
| `MQTT_USER` / `MQTT_PASS` | kosong | HiveMQ Cloud credentials |

## Topics

| Topic | Direction | Interval |
|-------|-----------|----------|
| `tracksafe/sender/{id}` | Sender → Broker | 1 detik |
| `tracksafe/heartbeat/{id}` | Sender → Broker | 10 detik |
| `tracksafe/alarm/{id}` | Sender → Broker | on rule change |
| `tracksafe/receiver/{id}` | Receiver → Broker | 10 detik |

Receiver subscribe: `tracksafe/sender/{pairedSender}`

## Rule Engine (Sender)

| Rule | Kondisi | Status | LED | Sirine |
|------|---------|--------|-----|--------|
| 1 | TOF >150cm, Limit LOW | SAFE | Hijau | OFF |
| 2 | TOF ≤150cm, Limit LOW | NOISE | Kuning | OFF |
| 3 | TOF ≤150cm, Limit HIGH | TRAIN | Merah | ON |

## Fitur

- MQTT publish/subscribe (HiveMQ)
- Offline queue + replay setelah reconnect
- Watchdog ESP32 (30s)
- Reconnect WiFi/GSM + MQTT otomatis
- Logging lengkap via Serial Monitor

## Upload

1. Buka `firmware/esp32_sender/tracksafe_sender/tracksafe_sender.ino`
2. Set WiFi + MQTT credentials
3. Upload ke board Sender
4. Ulangi untuk Receiver

## Testing tanpa hardware

```bash
cd backend
npm run dev          # REST + MQTT subscriber
npm run simulate:mqtt # publish test MQTT messages
```

Pairing tetap via Flutter → `POST /api/device/pair` (backend = source of truth).
