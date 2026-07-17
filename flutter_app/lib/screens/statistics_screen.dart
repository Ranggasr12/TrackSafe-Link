import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/statistic_card.dart';

/// Statistik TAHAP 1 — nol (belum ada history Firebase).
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, state, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Statistik Hari Ini',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data akan terisi setelah ada riwayat dari Firebase.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: const [
                StatisticCard(
                  title: 'Alarm Hari Ini',
                  value: '0',
                  icon: Icons.notifications_active,
                  color: AppColors.danger,
                ),
                StatisticCard(
                  title: 'Jumlah Noise',
                  value: '0',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.noise,
                ),
                StatisticCard(
                  title: 'Jumlah Danger',
                  value: '0',
                  icon: Icons.emergency,
                  color: AppColors.danger,
                ),
                StatisticCard(
                  title: 'Jumlah Normal',
                  value: '0',
                  icon: Icons.check_circle,
                  color: AppColors.normal,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Grafik Alarm Harian',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'Belum ada data grafik',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
