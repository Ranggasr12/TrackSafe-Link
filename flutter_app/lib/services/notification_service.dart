import 'alarm_service.dart';

/// Aksi notifikasi yang ditentukan oleh [NotificationService].
///
/// Mapping dari [AlarmLevel]:
/// - NONE     → none     : Tidak ada alarm
/// - WARNING  → warning  : Peringatan noise
/// - CRITICAL → critical : Bahaya kereta
/// - OFFLINE  → offline  : Perangkat offline
/// - UNKNOWN  → unknown  : Status tidak diketahui
enum NotificationAction {
  none,
  warning,
  critical,
  offline,
  unknown,
}

/// NotificationService — lapisan penerjemah [AlarmLevel] menjadi
/// aksi notifikasi yang siap digunakan oleh UI.
///
/// Tugas:
/// 1. Menerima [AlarmLevel] dari AlarmService
/// 2. Menentukan [NotificationAction] yang sesuai
/// 3. Menyediakan title & body untuk ditampilkan
///
/// TIDAK memanggil flutter_local_notifications.
/// TIDAK memanggil Awesome Notifications.
/// TIDAK memanggil Android Notification.
/// TIDAK memanggil Dialog / Snackbar.
/// TIDAK memanggil Sound / Vibrate.
/// TIDAK mengubah Provider / Dashboard / AlarmService.
///
/// Hanya pure Dart — tidak memerlukan dependency tambahan.
class NotificationService {
  NotificationService._();

  /// Mapping [AlarmLevel] ke [NotificationAction].
  ///
  /// | AlarmLevel   | NotificationAction |
  /// |--------------|-------------------|
  /// | none         | none              |
  /// | warning      | warning           |
  /// | critical     | critical          |
  /// | offline      | offline           |
  /// | unknown      | unknown           |
  static NotificationAction fromAlarmLevel(AlarmLevel level) {
    switch (level) {
      case AlarmLevel.none:
        return NotificationAction.none;
      case AlarmLevel.warning:
        return NotificationAction.warning;
      case AlarmLevel.critical:
        return NotificationAction.critical;
      case AlarmLevel.offline:
        return NotificationAction.offline;
      case AlarmLevel.unknown:
        return NotificationAction.unknown;
    }
  }

  /// Judul notifikasi berdasarkan [NotificationAction].
  ///
  /// | Action    | Title                     |
  /// |-----------|---------------------------|
  /// | none      | "TrackSafe Link"          |
  /// | warning   | "Peringatan"              |
  /// | critical  | "Bahaya"                  |
  /// | offline   | "Perangkat Offline"       |
  /// | unknown   | "Status Tidak Diketahui"  |
  static String title(NotificationAction action) {
    switch (action) {
      case NotificationAction.none:
        return 'TrackSafe Link';
      case NotificationAction.warning:
        return 'Peringatan';
      case NotificationAction.critical:
        return 'Bahaya';
      case NotificationAction.offline:
        return 'Perangkat Offline';
      case NotificationAction.unknown:
        return 'Status Tidak Diketahui';
    }
  }

  /// Isi / body notifikasi berdasarkan [NotificationAction].
  ///
  /// | Action    | Body                                         |
  /// |-----------|----------------------------------------------|
  /// | none      | "" (kosong)                                  |
  /// | warning   | "Noise terdeteksi pada jalur rel."           |
  /// | critical  | "Kereta terdeteksi. Segera menjauh dari..."  |
  /// | offline   | "Tidak ada komunikasi dengan perangkat..."   |
  /// | unknown   | "Belum ada data dari sistem."                |
  static String body(NotificationAction action) {
    switch (action) {
      case NotificationAction.none:
        return '';
      case NotificationAction.warning:
        return 'Noise terdeteksi pada jalur rel.';
      case NotificationAction.critical:
        return 'Kereta terdeteksi. Segera menjauh dari jalur rel.';
      case NotificationAction.offline:
        return 'Tidak ada komunikasi dengan perangkat ESP32.';
      case NotificationAction.unknown:
        return 'Belum ada data dari sistem.';
    }
  }

  /// Convenience: langsung dari [AlarmLevel] ke title.
  static String titleFromLevel(AlarmLevel level) {
    return title(fromAlarmLevel(level));
  }

  /// Convenience: langsung dari [AlarmLevel] ke body.
  static String bodyFromLevel(AlarmLevel level) {
    return body(fromAlarmLevel(level));
  }
}
