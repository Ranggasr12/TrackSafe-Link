import 'package:flutter/widgets.dart';

import 'alarm_audio_service.dart';
import 'alarm_service.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';

/// NotificationOrchestrator — status → notifikasi + alarm audio.
///
/// Singleton agar [_lastShownLevel] / [_lastProcessedLevel] tidak hilang
/// saat widget rebuild.
class NotificationOrchestrator {
  NotificationOrchestrator._({
    LocalNotificationService? localNotifications,
    AlarmAudioService? alarmAudio,
  })  : _local = localNotifications ?? LocalNotificationService.instance,
        _audio = alarmAudio ?? AlarmAudioService.instance;

  static final NotificationOrchestrator instance = NotificationOrchestrator._();

  final LocalNotificationService _local;
  final AlarmAudioService _audio;

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  AlarmLevel? _lastShownLevel;
  AlarmLevel? _lastProcessedLevel;

  AppLifecycleState get lifecycleState => _lifecycleState;

  void updateLifecycle(AppLifecycleState state) {
    _lifecycleState = state;
  }

  /// Evaluasi notifikasi + alarm audio berdasarkan status terkini.
  Future<void> evaluate({
    required String currentStatus,
    required bool notificationEnabled,
  }) async {
    final level = AlarmService.fromStatus(currentStatus);
    final levelUnchanged = _lastProcessedLevel == level;

    // Level sama → jangan stop()/play() ulang.
    if (!levelUnchanged) {
      await _syncAudio(level);
      _lastProcessedLevel = level;
    }

    if (!notificationEnabled) {
      await _local.cancelAll();
      _lastShownLevel = null;
      return;
    }

    // NORMAL → tidak mengirim; bersihkan notifikasi aktif.
    if (level == AlarmLevel.none) {
      await _local.cancelAll();
      _lastShownLevel = null;
      return;
    }

    // UNKNOWN → tidak mengirim.
    if (level == AlarmLevel.unknown) {
      _lastShownLevel = level;
      return;
    }

    // Anti-spam notifikasi: level sama → jangan kirim lagi.
    if (_lastShownLevel == level) {
      return;
    }

    final action = NotificationService.fromAlarmLevel(level);
    if (action == NotificationAction.none ||
        action == NotificationAction.unknown) {
      _lastShownLevel = level;
      return;
    }

    await _local.show(action);
    _lastShownLevel = level;

    debugPrint(
      '[NotificationOrchestrator] notified: $level '
      '(status=$currentStatus, lifecycle=$_lifecycleState)',
    );
  }

  Future<void> _syncAudio(AlarmLevel level) async {
    switch (level) {
      case AlarmLevel.none:
      case AlarmLevel.unknown:
        await _audio.stop();
      case AlarmLevel.warning:
        await _audio.playWarning();
      case AlarmLevel.critical:
        await _audio.playCritical();
      case AlarmLevel.offline:
        await _audio.playOffline();
    }
  }
}
