# TrackSafe Link Backend — Railway + HiveMQ MQTT

Express REST API + **persistent MQTT subscriber** dalam satu proses.

```
ESP32 → HiveMQ Cloud → Backend Railway → Firebase RTDB → Flutter
```

## Quick Start (Local)

```bash
cp .env.example .env
# isi FIREBASE_* dan MQTT_* (HiveMQ Cloud)
npm install
npm start
```

Server menjalankan **Express + MQTT subscriber** bersamaan.

## Railway Deployment

1. Buat project di [Railway](https://railway.app)
2. Connect repository, set **Root Directory** = `backend`
3. Add environment variables (lihat `.env.example`)
4. Deploy — Railway menjalankan `npm start` → `node server.js`
5. Health check otomatis: `GET /health`

### Environment Variables (Railway)

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | Auto | Railway sets automatically |
| `FIREBASE_PROJECT_ID` | Yes | Firebase project |
| `FIREBASE_CLIENT_EMAIL` | Yes | Service account email |
| `FIREBASE_PRIVATE_KEY` | Yes | PEM key (`\n` for newlines) |
| `FIREBASE_DATABASE_URL` | Yes | RTDB URL |
| `MQTT_HOST` | Yes | HiveMQ Cloud cluster host |
| `MQTT_PORT` | Yes | `8883` for TLS |
| `MQTT_TLS` | Yes | `true` for HiveMQ Cloud |
| `MQTT_USERNAME` | Yes | HiveMQ Cloud username |
| `MQTT_PASSWORD` | Yes | HiveMQ Cloud password |
| `MQTT_CLIENT_ID` | Yes | Unique client ID |

### Health Check

```http
GET /health
```

```json
{
  "success": true,
  "mqtt": "connected",
  "firebase": "connected",
  "uptime": 123.45,
  "timestamp": 1752600000000
}
```

## Endpoints

| Method | Path | Keterangan |
|--------|------|------------|
| GET | `/health` | Railway health (mqtt + firebase) |
| GET | `/api/status` | Legacy health check |
| POST | `/api/sensor` | Testing — sender telemetry (HTTP) |
| POST | `/api/device/register` | Register device |
| POST | `/api/device/heartbeat` | Heartbeat |
| POST | `/api/device/pair` | Pairing |
| POST | `/api/device/unpair` | Unpair |
| GET | `/api/history` | History |
| GET | `/api/device/list` | Device list |
| GET | `/api/backend/status` | Backend info + MQTT status |

**Produksi IoT:** ESP32 publish MQTT → backend subscriber. REST API untuk testing/debugging Flutter pairing.

## MQTT Topics (Subscribe: `tracksafe/#`)

| Topic | Handler |
|-------|---------|
| `tracksafe/sender/{id}` | `telemetry.service.js` |
| `tracksafe/receiver/{id}` | `device.service.js` |
| `tracksafe/heartbeat/{id}` | `device.service.js` |
| `tracksafe/alarm/{id}` | `alarm.service.js` |
| `tracksafe/config/{id}` | Firebase config node |
| `tracksafe/pairing/{id}` | `device.service.js` |

## Scripts

```bash
npm start              # Production (Railway)
npm run dev            # Local (same as start)
npm test               # Unit tests
npm run simulate:mqtt  # Publish test MQTT messages
npm run simulate:gps   # HTTP sensor simulator (testing)
```

## Architecture Notes

- **Railway:** persistent process, MQTT 24/7, Express on `PORT`
- **Legacy Vercel:** `api/index.js` still works for REST-only (no MQTT)
- **Flutter:** reads Firebase only; set `BACKEND_BASE_URL` to Railway URL for pair/unpair API

## Security

Never commit `.env` or service account JSON. Set secrets in Railway Variables dashboard.
