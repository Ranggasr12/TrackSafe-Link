# TrackSafe Link

Early Warning System Kereta Api — monorepo production.

```
TrackSafe-Link/
├── backend/       # Express.js → Vercel Serverless (ESP32 → Firebase RTDB)
├── flutter_app/   # Flutter Android monitoring app
├── README.md
└── .gitignore
```

## Architecture (V2 — MQTT HiveMQ)

```
Sender ESP32  ──MQTT publish──►  HiveMQ Broker
Receiver ESP32 ◄─MQTT sub/pub─┘         │
                                        ▼
                              Backend Node.js (MQTT subscriber + REST API)
                                        │
                                        ▼
                              Firebase Realtime Database
                                        │
                                        ▼
                              Flutter App (Firebase streams)
```

- **Produksi IoT:** ESP32 → MQTT → Backend subscriber → Firebase
- **Testing:** REST API (`POST /api/sensor`, dll.) tetap tersedia
- **Flutter:** tetap Firebase-only (tanpa MQTT client)

## Backend

```bash
cd backend
cp .env.example .env
# isi FIREBASE_* + MQTT_* (HiveMQ Cloud)
npm install
npm start            # Express + MQTT subscriber (local / Railway)
```

**Deploy ke Railway:** set Root Directory = `backend`, add ENV vars, deploy. Health check: `GET /health`.

Legacy Vercel REST-only masih tersedia via `api/index.js` (tanpa MQTT persistent).

Endpoints: `GET /api/status`, `POST /api/sensor`, `GET /api/device/:id`, `GET /api/history`.

**Secrets:** never commit `.env` or `serviceAccountKey*.json`. Set the same vars in Vercel Dashboard.

## Flutter

```bash
cd flutter_app
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=https://YOUR-APP.vercel.app
```

Release build:

```bash
flutter build apk --dart-define=BACKEND_BASE_URL=https://YOUR-APP.vercel.app
```

Without `BACKEND_BASE_URL`, Application Status uses Firebase heartbeat `backend/status` (not localhost).

## Device states

Sender / Receiver: `OFF` | `WAITING` | `CONNECTING` | `ONLINE` (timeout 30s).

## Security notes before GitHub push

1. Confirm root `.gitignore` is present.
2. Resolve nested `backend/.git` (remove nested repo if using monorepo) — do this manually.
3. Verify `git status` does **not** list `.env` or service account JSON.
4. Push only source + `.env.example`.

## License

Private / skripsi — TrackSafe Link.
