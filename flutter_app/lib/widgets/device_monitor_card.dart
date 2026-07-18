import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/device_link_status.dart';

/// Kartu monitoring perangkat IoT (Sender / Receiver) — Material 3.
class DeviceMonitorCard extends StatelessWidget {
  const DeviceMonitorCard({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.status,
    required this.batteryLabel,
    required this.signalLabel,
    required this.gpsFixLabel,
    required this.lastUpdateLabel,
  });

  final String title;
  final IconData leadingIcon;
  final DeviceLinkStatus status;
  final String batteryLabel;
  final String signalLabel;
  final String gpsFixLabel;
  final String lastUpdateLabel;

  ({IconData icon, Color color}) get _statusVisual {
    switch (status) {
      case DeviceLinkStatus.online:
        return (icon: Icons.check_circle, color: AppColors.online);
      case DeviceLinkStatus.off:
        return (icon: Icons.cancel, color: AppColors.offline);
      case DeviceLinkStatus.connecting:
        return (icon: Icons.sync, color: AppColors.warning);
      case DeviceLinkStatus.waiting:
        return (icon: Icons.schedule, color: AppColors.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _statusVisual;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: visual.color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(leadingIcon, size: 28, color: visual.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(visual.icon, size: 20, color: visual.color),
                const SizedBox(width: 6),
                Text(
                  status.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: visual.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MetricRow(
              icon: Icons.battery_full,
              label: 'Battery',
              value: batteryLabel,
            ),
            const SizedBox(height: 10),
            _MetricRow(
              icon: Icons.signal_cellular_alt,
              label: 'Signal GSM',
              value: signalLabel,
            ),
            const SizedBox(height: 10),
            _MetricRow(
              icon: Icons.gps_fixed,
              label: 'GPS Fix',
              value: gpsFixLabel,
            ),
            const SizedBox(height: 10),
            _MetricRow(
              icon: Icons.schedule,
              label: 'Last Update',
              value: lastUpdateLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
