import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/statistic_card.dart';

/// Statistik dari history Firebase realtime.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, state, _) {
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day)
            .millisecondsSinceEpoch;

        final todayItems = state.history.where((h) {
          final ts = h.timestamp < 1000000000000
              ? h.timestamp * 1000
              : h.timestamp;
          return ts >= todayStart;
        }).toList();

        final alarms = todayItems
            .where((h) => h.eventType == 'alarm' || h.status == SensorStatus.danger)
            .length;
        final noise = todayItems
            .where((h) =>
                h.eventType == 'sensor_warning' || h.status == SensorStatus.noise)
            .length;
        final danger = todayItems
            .where((h) => h.status == SensorStatus.danger)
            .length;
        final normal = todayItems
            .where((h) => h.status == SensorStatus.normal)
            .length;

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
              '${todayItems.length} event dari Firebase history',
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
              children: [
                StatisticCard(
                  title: 'Alarm Hari Ini',
                  value: '$alarms',
                  icon: Icons.notifications_active,
                  color: AppColors.danger,
                ),
                StatisticCard(
                  title: 'Jumlah Noise',
                  value: '$noise',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.noise,
                ),
                StatisticCard(
                  title: 'Jumlah Danger',
                  value: '$danger',
                  icon: Icons.emergency,
                  color: AppColors.danger,
                ),
                StatisticCard(
                  title: 'Jumlah Normal',
                  value: '$normal',
                  icon: Icons.check_circle,
                  color: AppColors.normal,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Event Terbaru',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if (todayItems.isEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'Belum ada event hari ini',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              )
            else
              ...todayItems.take(8).map(
                    (item) => ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 10,
                        color: item.status == SensorStatus.danger
                            ? AppColors.danger
                            : AppColors.primary,
                      ),
                      title: Text(item.eventLabel),
                      subtitle: Text(
                        item.description.isNotEmpty
                            ? item.description
                            : item.deviceId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        item.timeLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}
