import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Card indikator baterai — tampil `--` jika tidak ada data live.
class BatteryCard extends StatelessWidget {
  const BatteryCard({super.key, required this.percent});

  final int? percent;

  Color get _color {
    if (percent == null) return AppColors.unknown;
    if (percent! >= 60) return AppColors.normal;
    if (percent! >= 30) return AppColors.noise;
    return AppColors.danger;
  }

  IconData get _icon {
    if (percent == null) return Icons.battery_unknown;
    if (percent! >= 90) return Icons.battery_full;
    if (percent! >= 60) return Icons.battery_5_bar;
    if (percent! >= 30) return Icons.battery_3_bar;
    if (percent! >= 10) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 28, color: _color),
            const SizedBox(height: 10),
            Text(
              'Battery',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.battery(percent),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: _color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
