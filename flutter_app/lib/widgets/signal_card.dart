import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Card indikator signal — tampil `--` jika tidak ada data live.
class SignalCard extends StatelessWidget {
  const SignalCard({super.key, required this.signal});

  final int? signal;

  Color get _color {
    if (signal == null) return AppColors.unknown;
    if (signal! < 0) {
      if (signal! >= -60) return AppColors.normal;
      if (signal! >= -75) return AppColors.noise;
      return AppColors.danger;
    }
    if (signal! >= 20) return AppColors.normal;
    if (signal! >= 10) return AppColors.noise;
    return AppColors.danger;
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
            Icon(
              signal == null
                  ? Icons.signal_cellular_nodata
                  : Icons.signal_cellular_alt,
              color: _color,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'Signal',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.signal(signal),
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
