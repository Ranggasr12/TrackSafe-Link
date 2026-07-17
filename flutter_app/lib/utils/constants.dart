/// Konstanta aplikasi TrackSafe Link.
class AppConstants {
  AppConstants._();

  static const String appName = 'TrackSafe Link';
  static const String appTagline = 'Early Warning System Kereta Api';
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
  /// `flutter run --dart-define=BACKEND_BASE_URL=https://your-app.vercel.app`
  static const String backendHealthUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

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
    if (upper == unknown || upper == offline) return upper;
    return unknown;
  }

  static bool isLiveEsp32(String status) => esp32Statuses.contains(status);
}
