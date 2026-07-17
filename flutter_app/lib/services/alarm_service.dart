import '../utils/constants.dart';

/// Level alarm yang ditentukan oleh [AlarmService].
///
/// - NONE     : Tidak ada alarm — status NORMAL
/// - WARNING  : Peringatan — status NOISE
/// - CRITICAL : Bahaya — status DANGER
/// - OFFLINE  : Perangkat offline — status OFFLINE
/// - UNKNOWN  : Belum ada data — status UNKNOWN
enum AlarmLevel {
  none,
  warning,
  critical,
  offline,
  unknown,
}

/// AlarmService — engine penentu level alarm.
///
/// Tugas: menerima [currentStatus] dari MonitoringProvider,
/// mengembalikan [AlarmLevel] yang sesuai.
///
/// TIDAK memutar suara.
/// TIDAK membuat notifikasi.
/// TIDAK membuat dialog.
/// TIDAK mengubah UI.
///
/// Hanya logic mapping: status → level alarm.
class AlarmService {
  AlarmService._();

  /// Mapping status ke level alarm.
  ///
  /// | Status    | AlarmLevel |
  /// |-----------|------------|
  /// | NORMAL    | NONE       |
  /// | NOISE     | WARNING    |
  /// | DANGER    | CRITICAL   |
  /// | OFFLINE   | OFFLINE    |
  /// | UNKNOWN   | UNKNOWN    |
  static AlarmLevel fromStatus(String status) {
    switch (status.toUpperCase().trim()) {
      case SensorStatus.normal:
        return AlarmLevel.none;
      case SensorStatus.noise:
        return AlarmLevel.warning;
      case SensorStatus.danger:
        return AlarmLevel.critical;
      case SensorStatus.offline:
        return AlarmLevel.offline;
      case SensorStatus.unknown:
      default:
        return AlarmLevel.unknown;
    }
  }

  /// Deskripsi singkat level alarm untuk logging / debugging.
  static String describe(AlarmLevel level) {
    switch (level) {
      case AlarmLevel.none:
        return 'Tidak ada alarm — aman.';
      case AlarmLevel.warning:
        return 'Peringatan — noise terdeteksi.';
      case AlarmLevel.critical:
        return 'KRITIS — kereta terdeteksi!';
      case AlarmLevel.offline:
        return 'Perangkat offline — tidak ada data.';
      case AlarmLevel.unknown:
        return 'Belum ada data — status tidak diketahui.';
    }
  }
}
