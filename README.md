# TrackSafe Link

Early Warning System Kereta Api — monorepo production.

```
TrackSafe-Link/
├── backend/       # Express.js → Vercel Serverless (ESP32 → Firebase RTDB)
├── flutter_app/   # Flutter Android monitoring app
├── README.md
└── .gitignore
```

## Architecture

```
ESP32  →  POST /api/sensor  →  Backend (Vercel)  →  Firebase RTDB
                                                      ↓
                                              Flutter (realtime)
```

No MQTT. No rule-based status on backend — ESP32 sends final `NORMAL` | `NOISE` | `DANGER`.

## Backend

```bash
cd backend
cp .env.example .env
# isi FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY, FIREBASE_DATABASE_URL
npm install
npm run dev          # local: http://localhost:3000
vercel --prod        # production
```

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
