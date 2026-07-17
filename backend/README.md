# TrackSafe Link Backend (Vercel Serverless)

Express.js HTTP bridge: **ESP32 → Backend → Firebase RTDB → Flutter**.

Tidak ada MQTT. Tidak ada `app.listen()` di production. Tidak ada rule-based.

## Endpoints

| Method | Path | Keterangan |
|--------|------|------------|
| GET | `/api/status` | Backend + Firebase health |
| POST | `/api/sensor` | Terima payload ESP32 |
| GET | `/api/device/:deviceId` | Baca device |
| GET | `/api/history` | Riwayat status |

### Contoh `GET /api/status`

```json
{
  "success": true,
  "backend": "online",
  "firebase": "connected"
}
```

### Contoh `POST /api/sensor`

```json
{
  "deviceId": "sender01",
  "status": "DANGER",
  "distance": 340,
  "battery": 91,
  "signal": 24,
  "timestamp": 1752600000
}
```

## Environment Variables (Vercel Dashboard)

Set di **Project → Settings → Environment Variables**:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY` (gunakan `\n` untuk newline)
- `FIREBASE_DATABASE_URL`

Jangan commit `serviceAccountKey.json`.

## Local

```bash
cp .env.example .env
# isi credential
npm install
npm run dev
```

## Deploy

```bash
vercel --prod
```

Root Directory di Vercel harus `backend` (atau deploy dari folder ini).
