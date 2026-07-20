import '../models/monitoring_model.dart';
import 'offline_detector.dart';

/// State machine koneksi perangkat IoT (Sender / Receiver).
///
/// OFF → WAITING → CONNECTING → ONLINE
///
/// Sumber utama: Backend Device Status Engine (`linkStatus` di Firebase).
/// Fallback lokal hanya jika field belum tersedia (kompatibilitas sprint lama).
enum DeviceLinkStatus {
  off,
  waiting,
  connecting,
  online,
}

extension DeviceLinkStatusLabel on DeviceLinkStatus {
  String get label {
    switch (this) {
      case DeviceLinkStatus.off:
        return 'OFF';
      case DeviceLinkStatus.waiting:
        return 'WAITING';
      case DeviceLinkStatus.connecting:
        return 'CONNECTING';
      case DeviceLinkStatus.online:
        return 'ONLINE';
    }
  }
}

/// Resolver status perangkat IoT untuk dashboard cards.
class DeviceLinkStatusResolver {
  DeviceLinkStatusResolver._();

  static const String noDataLabel = '—';

  /// Parse status dari Backend Device Status Engine.
  static DeviceLinkStatus? fromBackend(String? raw) {
    if (raw == null) return null;
    switch (raw.toUpperCase().trim()) {
      case 'OFF':
        return DeviceLinkStatus.off;
      case 'WAITING':
        return DeviceLinkStatus.waiting;
      case 'CONNECTING':
        return DeviceLinkStatus.connecting;
      case 'ONLINE':
        return DeviceLinkStatus.online;
      default:
        return null;
    }
  }

  /// ONLINE membutuhkan Battery + Signal + Status (+ GPS jika [requireGps]).
  static bool hasCoreTelemetry(MonitoringModel? m) {
    if (m == null || !m.hasData) return false;
    if (m.battery == null || m.signal == null) return false;
    if (m.status.trim().isEmpty) return false;
    return true;
  }

  static bool hasHeartbeat(MonitoringModel? m) {
    if (m == null || !m.hasData) return false;
    return m.effectiveTimeMs > 0 || m.online;
  }

  static bool isFresh(MonitoringModel? m) {
    if (m == null || !m.hasData) return false;
    return !OfflineDetector.isOffline(m);
  }

  static bool gpsFixFromCoords(double? lat, double? lng) {
    return lat != null && lng != null;
  }

  /// Utamakan [MonitoringModel.linkStatus] dari backend.
  /// Timeout / freshness dihitung di Backend Status Engine.
  static DeviceLinkStatus resolve({
    required bool isLoading,
    required bool seenThisSession,
    required MonitoringModel? telemetry,
    required bool hasGpsFix,
  }) {
    if (isLoading) return DeviceLinkStatus.connecting;

    final backendStatus = fromBackend(telemetry?.linkStatus);
    if (backendStatus != null) return backendStatus;

    // Fallback sprint lama — hanya jika backend belum menulis linkStatus.
    final fresh = isFresh(telemetry);
    final heartbeat = hasHeartbeat(telemetry);
    final core = hasCoreTelemetry(telemetry);
    final full = core && hasGpsFix;

    if (fresh && full) return DeviceLinkStatus.online;

    if (fresh && heartbeat && !full) return DeviceLinkStatus.connecting;

    if (seenThisSession) return DeviceLinkStatus.off;

    if (heartbeat && !fresh) return DeviceLinkStatus.off;

    return DeviceLinkStatus.waiting;
  }
}
