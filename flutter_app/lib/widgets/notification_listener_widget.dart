import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../services/alarm_audio_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_orchestrator.dart';
import '../utils/app_stage.dart';

/// Mendengarkan perubahan [MonitoringProvider.currentStatus] & lifecycle,
/// lalu memicu [NotificationOrchestrator] hanya saat status berubah.
class NotificationListenerWidget extends StatefulWidget {
  const NotificationListenerWidget({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NotificationListenerWidget> createState() =>
      _NotificationListenerWidgetState();
}

class _NotificationListenerWidgetState extends State<NotificationListenerWidget>
    with WidgetsBindingObserver {
  final NotificationOrchestrator _orchestrator =
      NotificationOrchestrator.instance;
  String? _lastEvaluatedStatus;
  bool? _lastNotificationEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlarmAudioService.instance.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hanya update lifecycle — jangan evaluate ulang jika status tidak berubah.
    _orchestrator.updateLifecycle(state);
  }

  void _scheduleEvaluate() {
    if (!AppStage.localNotificationEnabled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _evaluate();
    });
  }

  Future<void> _evaluate() async {
    if (!AppStage.localNotificationEnabled) return;

    final monitoring = context.read<MonitoringProvider>();
    final settings = context.read<SettingsProvider>();

    await _orchestrator.evaluate(
      currentStatus: monitoring.currentStatus,
      notificationEnabled: settings.notificationEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppStage.localNotificationEnabled) {
      return widget.child;
    }

    return Consumer2<MonitoringProvider, SettingsProvider>(
      builder: (context, monitoring, settings, child) {
        final status = monitoring.currentStatus;
        final enabled = settings.notificationEnabled;

        // evaluate HANYA saat currentStatus benar-benar berubah.
        if (status != _lastEvaluatedStatus) {
          _lastEvaluatedStatus = status;
          _lastNotificationEnabled = enabled;
          _scheduleEvaluate();
        } else if (enabled != _lastNotificationEnabled) {
          // Toggle settings saja — orchestrator skip audio jika level sama.
          _lastNotificationEnabled = enabled;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await _orchestrator.evaluate(
              currentStatus: status,
              notificationEnabled: enabled,
            );
          });
        }

        return child!;
      },
      child: widget.child,
    );
  }
}

/// Request permission saat notifikasi diaktifkan dari Settings.
Future<void> requestNotificationPermissionIfNeeded(bool enabled) async {
  if (!enabled || !AppStage.localNotificationEnabled) return;
  await LocalNotificationService.instance.requestPermission();
}
