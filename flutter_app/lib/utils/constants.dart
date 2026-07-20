/// Konstanta aplikasi TrackSafe Link.
class AppConstants {
  AppConstants._();

  static const String appName = 'TrackSafe Link';
  static const String appTagline = 'Early Warning System Kereta Api';
  /// Placeholder Device ID untuk model kosong / history legacy saja.
  /// Device ID runtime berasal dari Device Pairing (SharedPreferences).
  static const String defaultDeviceId = 'sender01';

  static const String devicesPath = 'devices';
  static const String historyPath = 'history';
  static const String backendStatusPath = 'backend/status';

  /// Timeout perangkat OFF (Sender / Receiver) — Sprint 30: 30 detik.
  static const int senderOfflineThresholdSec = 30;

  /// Dipakai mulai TAHAP 7.
  static const int acknowledgeReArmSec = 5;

  /// Base URL backend production (tanpa trailing slash).
  ///
  /// Override saat build:
  /// `flutter run --dart-define=BACKEND_BASE_URL=https://other.vercel.app`
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://track-safe-link.vercel.app',
  );

  /// Alias untuk health check Application Status (GET /api/status).
  static const String backendHealthUrl = backendBaseUrl;

  /// Interval poll Application Status (detik).
  static const int statusPollIntervalSec = 15;

  /// Heartbeat Firebase `backend/status` dianggap segar (detik).
  /// Cukup longgar agar status backend tetap akurat antar poll ESP32.
  static const int backendHeartbeatFreshSec = 120;

  static const String prefAlarmVolume = 'alarm_volume';
  static const String prefVibration = 'vibration_enabled';
  static const String prefNotification = 'notification_enabled';
  static const String prefDarkMode = 'dark_mode';
  static const String prefDeviceId = 'device_id';

  /// Device Pairing (Sprint 31.3) — menggantikan Device ID hardcoded.
  static const String prefSenderId = 'paired_sender_id';
  static const String prefReceiverId = 'paired_receiver_id';
  static const String prefLastConnectedMs = 'paired_last_connected_ms';
}

/// Status sensor / overlay tampilan.
class SensorStatus {
  SensorStatus._();

  static const String unknown = 'UNKNOWN';
  static const String normal = 'NORMAL';
  static const String noise = 'NOISE';
  static const String danger = 'DANGER';
  static const String offline = 'OFFLINE';

  static const Set<String> esp32Statuses = {normal, noise, danger};

  static String fromEsp32(String? raw) {
    if (raw == null || raw.trim().isEmpty) return unknown;
    final upper = raw.toUpperCase().trim();
    if (esp32Statuses.contains(upper)) return upper;
    // MQTT V2 aliases (backend maps to NORMAL/DANGER; fallback for direct reads)
    if (upper == 'SAFE') return normal;
    if (upper == 'TRAIN') return danger;
    if (upper == unknown || upper == offline) return upper;
    return unknown;
  }

  static bool isLiveEsp32(String status) => esp32Statuses.contains(status);
}
