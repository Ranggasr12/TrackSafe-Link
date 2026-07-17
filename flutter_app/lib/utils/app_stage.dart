/// Tahap pengembangan TrackSafe Link (skripsi).
///
/// Naikkan nilai ini hanya setelah tahap saat ini selesai & diuji.
/// 1 = Flutter UI
/// 2 = Firebase
/// 3 = Backend Express (local)
/// 4 = Integrasi Flutter ↔ Backend
/// 5 = ESP32
/// 6 = Monitoring timeout
/// 7 = Alarm
/// 8 = Deploy Vercel
/// 11 = Local Notification
class AppStage {
  AppStage._();

  /// Tahap aktif saat ini.
  static const int current = 11;

  static const bool firebaseEnabled = current >= 2;
  static const bool backendEnabled = current >= 3;
  static const bool backendHealthCheckEnabled = current >= 4;
  static const bool esp32Expected = current >= 5;
  static const bool offlineTimeoutEnabled = current >= 6;
  static const bool alarmEnabled = current >= 7;
  static const bool localNotificationEnabled = current >= 11;
}
