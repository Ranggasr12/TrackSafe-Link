import 'package:flutter/foundation.dart';

import 'alarm_audio_service.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';
import '../utils/constants.dart';

/// NotificationOrchestrator — status → notifikasi + alarm audio.
///
/// Sesuai arsitektur final TrackSafe:
/// - Ketika status berubah menjadi DANGER:
///   1. Local Notification (flutter_local_notifications)
///   2. Alarm Audio (audioplayers)
///   3. Vibration
/// - Tidak perlu request ke backend.
///
/// Edge detection:
/// Audio HANYA berbunyi pada transisi:
///   SAFE → NOISE
///   SAFE → DANGER
///   NOISE → DANGER
/// Audio BERHENTI pada:
///   DANGER → SAFE
///   NOISE → SAFE
/// Transisi dari UNKNOWN/OFFLINE tidak memicu audio (startup/reconnect).
class NotificationOrchestrator {
  NotificationOrchestrator({
    LocalNotificationService? localNotifications,
    AlarmAudioService? alarmAudio,
  })  : _local = localNotifications ?? LocalNotificationService.instance,
        _audio = alarmAudio ?? AlarmAudioService.instance;

  final LocalNotificationService _local;
  final AlarmAudioService _audio;

  String _previousStatus = '';
  bool _initialized = false;

  /// Initialize orchestrator.
  Future<void> initialize() async {
    if (_initialized) return;
    await _audio.initialize();
    _initialized = true;
    debugPrint('[NotificationOrchestrator] Initialized');
  }

  /// Evaluasi notifikasi + alarm audio berdasarkan status terkini.
  ///
  /// [currentStatus] adalah currentStatus dari MonitoringProvider.
  ///
  /// Edge detection menggunakan _previousStatus:
  /// - Hanya trigger audio pada transisi tertentu
  /// - Transisi dari UNKNOWN/OFFLINE tidak memicu audio
  /// - Status yang sama tidak memicu audio ulang
  Future<void> evaluate({
    required String currentStatus,
    required bool notificationEnabled,
  }) async {
    if (!_initialized) await initialize();

    final normalizedStatus = currentStatus.toUpperCase().trim();
    final normalizedPrevious = _previousStatus.toUpperCase().trim();

    // Jika status sama, jangan lakukan apa-apa
    if (normalizedStatus == normalizedPrevious) return;

    // Edge detection untuk audio
    await _handleEdgeTransition(
      previousStatus: normalizedPrevious,
      currentStatus: normalizedStatus,
      notificationEnabled: notificationEnabled,
    );

    _previousStatus = normalizedStatus;
  }

  /// Edge detection: tentukan aksi audio berdasarkan transisi status.
  ///
  /// Transisi yang memicu audio:
  ///   SAFE → NOISE     : playWarning
  ///   SAFE → DANGER    : playCritical + notification
  ///   NOISE → DANGER   : playCritical + notification
  ///
  /// Transisi yang menghentikan audio:
  ///   DANGER → SAFE    : stop
  ///   NOISE → SAFE     : stop
  ///   DANGER → NOISE   : playWarning (turun level)
  ///
  /// Transisi dari UNKNOWN/OFFLINE → apapun: TIDAK memicu audio
  /// Transisi ke UNKNOWN/OFFLINE: stop audio
  Future<void> _handleEdgeTransition({
    required String previousStatus,
    required String currentStatus,
    required bool notificationEnabled,
  }) async {
    // Jangan trigger audio jika previous adalah UNKNOWN atau OFFLINE
    // (startup aplikasi, reconnect firebase, backend offline, dll)
    if (previousStatus == SensorStatus.unknown ||
        previousStatus == SensorStatus.offline ||
        previousStatus == '') {
      // Hanya stop audio jika current bukan UNKNOWN/OFFLINE
      if (currentStatus == SensorStatus.unknown ||
          currentStatus == SensorStatus.offline) {
        await _audio.stop();
      }
      // Transisi dari UNKNOWN/OFFLINE → SAFE/NOISE/DANGER: jangan bunyi
      return;
    }

    // Transisi yang memicu DANGER alarm
    if (currentStatus == SensorStatus.danger) {
      if (previousStatus == SensorStatus.safe ||
          previousStatus == SensorStatus.normal ||
          previousStatus == SensorStatus.noise) {
        if (notificationEnabled) {
          await _local.show(NotificationAction.critical);
        }
        await _audio.playCritical();
        return;
      }
    }

    // Transisi yang memicu NOISE warning
    if (currentStatus == SensorStatus.noise) {
      if (previousStatus == SensorStatus.safe ||
          previousStatus == SensorStatus.normal) {
        await _audio.playWarning();
        return;
      }
      // NOISE → NOISE sudah di-handle di atas (return early)
      // DANGER → NOISE: turun level, play warning
      if (previousStatus == SensorStatus.danger) {
        await _audio.playWarning();
        return;
      }
    }

    // Transisi ke SAFE: stop audio
    if (currentStatus == SensorStatus.safe ||
        currentStatus == SensorStatus.normal) {
      await _audio.stop();
      return;
    }

    // Transisi ke UNKNOWN atau OFFLINE: stop audio
    if (currentStatus == SensorStatus.unknown ||
        currentStatus == SensorStatus.offline) {
      await _audio.stop();
      return;
    }
  }

  void dispose() {
    _previousStatus = '';
  }
}
