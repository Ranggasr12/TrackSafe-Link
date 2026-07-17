# TrackSafe Link — Flutter EWS

Early Warning System untuk keselamatan pekerja rel kereta api.

## Arsitektur

```
ESP32 (Rule-Based) → HTTP POST → Express Backend → Firebase RTDB → Flutter
```

Flutter **tidak** menjalankan rule-based. Status `NORMAL` / `NOISE` / `DANGER` ditampilkan apa adanya dari Firebase.

## Firebase path

| Path | Isi |
|------|-----|
| `devices/{deviceId}` | Data live monitoring |
| `history/{id}` | Riwayat perubahan status |
| `backend/status` | Heartbeat backend |

## Fitur aplikasi

- Dashboard realtime (StatusCard NORMAL / NOISE / DANGER)
- Fullscreen alarm + suara loop saat DANGER
- Acknowledge lokal (ACK) — tidak mengubah Firebase
- Re-arm alarm setelah 5 detik jika masih DANGER
- Local notification saat app background (transisi ke DANGER)
- History + detail
- Statistik harian + grafik alarm
- Setting: volume, vibration, notification, dark mode

## Menjalankan

```bash
cd flutter_app
flutter pub get
flutter run
```

## Backend

```bash
cd backend
npm install
npm start
```

ESP32 kirim ke `POST /api/telemetry`:

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
