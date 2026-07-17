import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

/// LocalNotificationService — wrapper [flutter_local_notifications].
///
/// Tugas:
/// - Init plugin & notification channels
/// - Request permission (Android 13+)
/// - Show / cancel system notifications
///
/// TIDAK membaca Firebase.
/// TIDAK menentukan status alarm — menerima [NotificationAction] siap pakai.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String channelCritical = 'tracksafe_critical';
  static const String channelWarning = 'tracksafe_warning';
  static const String channelOffline = 'tracksafe_offline';
  static const String channelUnknown = 'tracksafe_unknown';

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(initSettings);
    await _createAndroidChannels();
    _initialized = true;

    debugPrint('[LocalNotificationService] Initialized');
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelCritical,
        'Bahaya Kereta',
        description: 'Notifikasi saat kereta terdeteksi (DANGER)',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelWarning,
        'Peringatan Noise',
        description: 'Notifikasi saat noise terdeteksi (NOISE)',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelOffline,
        'Perangkat Offline',
        description: 'Notifikasi saat ESP32 tidak merespons',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelUnknown,
        'Status Tidak Diketahui',
        description: 'Notifikasi saat belum ada data sistem',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// Request runtime permission (Android 13+). No-op on unsupported platforms.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<void> show(NotificationAction action) async {
    if (!_initialized) {
      debugPrint('[LocalNotificationService] show skipped — not initialized');
      return;
    }

    if (action == NotificationAction.none) {
      await cancelAll();
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId(action),
        _channelName(action),
        channelDescription: _channelDescription(action),
        importance: _importance(action),
        priority: _priority(action),
        playSound: action != NotificationAction.unknown,
        enableVibration: action != NotificationAction.unknown,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      _notificationId(action),
      NotificationService.title(action),
      NotificationService.body(action),
      details,
    );

    debugPrint('[LocalNotificationService] show: $action');
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  static int _notificationId(NotificationAction action) {
    switch (action) {
      case NotificationAction.critical:
        return 1;
      case NotificationAction.warning:
        return 2;
      case NotificationAction.offline:
        return 3;
      case NotificationAction.unknown:
        return 4;
      case NotificationAction.none:
        return 0;
    }
  }

  static String _channelId(NotificationAction action) {
    switch (action) {
      case NotificationAction.critical:
        return channelCritical;
      case NotificationAction.warning:
        return channelWarning;
      case NotificationAction.offline:
        return channelOffline;
      case NotificationAction.unknown:
        return channelUnknown;
      case NotificationAction.none:
        return channelUnknown;
    }
  }

  static String _channelName(NotificationAction action) {
    switch (action) {
      case NotificationAction.critical:
        return 'Bahaya Kereta';
      case NotificationAction.warning:
        return 'Peringatan Noise';
      case NotificationAction.offline:
        return 'Perangkat Offline';
      case NotificationAction.unknown:
        return 'Status Tidak Diketahui';
      case NotificationAction.none:
        return 'TrackSafe Link';
    }
  }

  static String _channelDescription(NotificationAction action) {
    switch (action) {
      case NotificationAction.critical:
        return 'Kereta terdeteksi pada jalur rel';
      case NotificationAction.warning:
        return 'Noise terdeteksi pada jalur rel';
      case NotificationAction.offline:
        return 'ESP32 tidak merespons';
      case NotificationAction.unknown:
        return 'Belum ada data dari sistem';
      case NotificationAction.none:
        return '';
    }
  }

  static Importance _importance(NotificationAction action) {
    switch (action) {
      case NotificationAction.critical:
        return Importance.max;
      case NotificationAction.warning:
      case NotificationAction.offline:
        return Importance.high;
      case NotificationAction.unknown:
        return Importance.defaultImportance;
      case NotificationAction.none:
        return Importance.low;
    }
  }

  static Priority _priority(NotificationAction action) {
    switch (action) {
      case NotificationAction.critical:
        return Priority.max;
      case NotificationAction.warning:
      case NotificationAction.offline:
        return Priority.high;
      case NotificationAction.unknown:
        return Priority.defaultPriority;
      case NotificationAction.none:
        return Priority.low;
    }
  }
}
