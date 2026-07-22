/// Konstanta aplikasi TrackSafe Link.
class AppConstants {
  AppConstants._();

  static const String appName = 'TrackSafe Link';
  static const String appTagline = 'Early Warning System Kereta Api';

  /// Placeholder Device ID untuk model kosong / history legacy saja.
  static const String defaultDeviceId = 'sender01';

  static const String devicesPath = 'devices';
  static const String historyPath = 'history';
  static const String backendStatusPath = 'backend/status';

  /// Timeout perangkat OFF — 15 detik sesuai arsitektur final.
  static const int senderOfflineThresholdSec = 15;

  /// Dipakai mulai TAHAP 7.
  static const int acknowledgeReArmSec = 5;

  /// Base URL backend production (tanpa trailing slash).
  ///
  /// Override saat build:
  /// `flutter run --dart-define=BACKEND_BASE_URL=https://your-backend.railway.app`
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://track-safe-link.railway.app',
  );

  /// Alias untuk health check Application Status.
  static const String backendHealthUrl = backendBaseUrl;

  /// Interval check Application Status via Firebase (detik).
  /// TIDAK polling HTTP — membaca dari Firebase Realtime Database.
  static const int statusPollIntervalSec = 15;

  /// Heartbeat Firebase `backend/status` dianggap segar (detik).
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

  // --------------------------------------------------
  // RULE BASE — Arsitektur Final TrackSafe
  // --------------------------------------------------

  /// Threshold jarak untuk status NOISE/DANGER (cm).
  static const int distanceThresholdCm = 150;

  /// Status ESP32
  static const String statusSafe = 'SAFE';
  static const String statusNoise = 'NOISE';
  static const String statusDanger = 'DANGER';
  static const String statusOffline = 'OFFLINE';
  static const String statusUnknown = 'UNKNOWN';

  /// Label event history
  static const String eventOnline = 'ONLINE';
  static const String eventOffline = 'OFFLINE';
  static const String eventPair = 'PAIR';
  static const String eventUnpair = 'UNPAIR';

  /// Default GPS position (Bandung).
  static const double defaultLatitude = -6.914744;
  static const double defaultLongitude = 107.609810;
}

/// Status sensor / overlay tampilan.
class SensorStatus {
  SensorStatus._();

  static const String unknown = 'UNKNOWN';
  static const String normal = 'NORMAL';
  static const String noise = 'NOISE';
  static const String danger = 'DANGER';
  static const String offline = 'OFFLINE';
  static const String safe = 'SAFE';

  static const Set<String> esp32Statuses = {safe, noise, danger};

  static String fromEsp32(String? raw) {
    if (raw == null || raw.trim().isEmpty) return unknown;
    final upper = raw.toUpperCase().trim();
    if (esp32Statuses.contains(upper)) return upper;
    // Alias backward compatibility
    if (upper == 'NORMAL') return safe;
    if (upper == 'TRAIN') return danger;
    if (upper == unknown || upper == offline) return upper;
    return unknown;
  }

  static bool isLiveEsp32(String status) => esp32Statuses.contains(status);
}

/// Rule Base Engine — menentukan status berdasarkan distance & limitSwitch.
class RuleBase {
  RuleBase._();

  static String evaluate({
    required int distance,
    String? limitSwitch,
  }) {
    final isHigh = limitSwitch?.toUpperCase().trim() == 'HIGH';

    if (distance > AppConstants.distanceThresholdCm) {
      return AppConstants.statusSafe;
    }

    if (isHigh) {
      return AppConstants.statusDanger;
    }

    return AppConstants.statusNoise;
  }

  static String statusColor(String status) {
    switch (status.toUpperCase().trim()) {
      case 'SAFE':
      case 'NORMAL':
        return 'HIJAU';
      case 'NOISE':
        return 'KUNING';
      case 'DANGER':
        return 'MERAH';
      default:
        return 'ABU-ABU';
    }
  }

  static bool isSirenOn(String status) {
    return status.toUpperCase().trim() == AppConstants.statusDanger;
  }

  static bool needsHistoryLog(String status) {
    final s = status.toUpperCase().trim();
    return s == AppConstants.statusNoise || s == AppConstants.statusDanger;
  }
}
