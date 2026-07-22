import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/history_model.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/statistic_card.dart';

/// Statistik dari history Firebase realtime.
/// Menggunakan sumber data yang SAMA dengan HistoryScreen:
/// `state.history` dari Firebase `history/` stream.
/// Filter hanya alarm Rule Base: SAFE, NOISE, DANGER.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  /// Filter: hanya tampilkan alarm Rule Base (SAFE, NOISE, DANGER).
  /// Sama persis dengan HistoryScreen.filterAlarmOnly().
  ///
  /// Fleksibel terhadap eventType — hitung selama status adalah SAFE/NOISE/DANGER
  /// dan eventType BUKAN event sistem (ONLINE, OFFLINE, PAIR, dll).
  static List<HistoryModel> filterAlarmOnly(List<HistoryModel> items) {
    // System event types yang HARUS dikecualikan
    const systemEvents = <String>{
      'ONLINE',
      'OFFLINE',
      'PAIR',
      'UNPAIR',
      'PAIRING',
      'UNPAIRING',
      'CONNECT',
      'DISCONNECT',
      'CONNECTED',
      'DISCONNECTED',
      'BACKEND_RESTART',
      'SERVER_START',
      'DEVICE_REGISTER',
      'HEARTBEAT',
      'GPS_UPDATE',
      'BATTERY',
      'SIGNAL',
      'MQTT_CONNECTED',
      'MQTT_DISCONNECTED',
      'SYSTEM',
      'BATTERY_UPDATE',
      'SIGNAL_UPDATE',
      'BACKEND_ONLINE',
      'BACKEND_OFFLINE',
    };

    return items.where((item) {
      final s = item.status.toString().toUpperCase().trim();

      // Status harus SAFE, NOISE, atau DANGER
      if (s != 'SAFE' && s != 'NOISE' && s != 'DANGER') return false;

      // eventType — jika merupakan event sistem, buang
      final et = item.eventType.toString().toUpperCase().trim();
      if (systemEvents.contains(et)) return false;

      // eventType null atau kosong — izinkan (anggap alarm)
      // eventType = status_change, alarm, atau apapun yg bukan sistem — izinkan
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Konversi timestamp dari Firebase ke milliseconds since epoch.
  ///
  /// Firebase menyimpan timestamp dalam Unix DETIK (Math.floor(nowMs / 1000)).
  /// Jika nilai < 1 triliun, itu adalah detik → kalikan 1000.
  /// Jika nilai >= 1 triliun, itu sudah milidetik → gunakan langsung.
  static int _toMs(int rawTimestamp) {
    return rawTimestamp < 1000000000000 ? rawTimestamp * 1000 : rawTimestamp;
  }

  /// Hitung statistik untuk suatu periode.
  static Map<String, int> _countByStatus(List<HistoryModel> items) {
    int safe = 0, noise = 0, danger = 0;
    for (final item in items) {
      final s = item.status.toString().toUpperCase().trim();
      if (s == 'SAFE') safe++;
      if (s == 'NOISE') noise++;
      if (s == 'DANGER') danger++;
    }
    return {'SAFE': safe, 'NOISE': noise, 'DANGER': danger};
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, state, _) {
        final now = DateTime.now();
        final nowMs = now.millisecondsSinceEpoch;

        // Start of today (00:00:00.000) dalam milliseconds
        final startOfTodayMs =
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

        // Start of 7 days ago dalam milliseconds
        final startOf7DaysMs = nowMs - const Duration(days: 7).inMilliseconds;

        // Debug: log total history received
        debugPrint('[STATISTICS] History total: ${state.history.length}');

        // Gunakan data yang SAMA dengan HistoryScreen: state.history
        // Filter hanya alarm Rule Base (SAFE, NOISE, DANGER)
        final allAlarms = filterAlarmOnly(state.history);

        // Debug: log after filterAlarmOnly
        debugPrint('[STATISTICS] After filterAlarmOnly: ${allAlarms.length}');

        // Debug: log timestamps of filtered items with detailed math
        for (final item in allAlarms) {
          final rawTs = item.timestamp;
          final convertedMs = _toMs(rawTs);
          final convertedDate =
              DateTime.fromMillisecondsSinceEpoch(convertedMs);
          final isToday = convertedMs >= startOfTodayMs;
          final is7Days = convertedMs >= startOf7DaysMs;

          debugPrint(
            '[STAT] now=$nowMs '
            'startToday=$startOfTodayMs '
            'start7Days=$startOf7DaysMs '
            'item.timestamp=$rawTs '
            'convertedMs=$convertedMs '
            'convertedDate=${convertedDate.toIso8601String()} '
            'isToday=$isToday '
            'is7Days=$is7Days '
            'status=${item.status} '
            'eventType=${item.eventType}',
          );
        }

        // Filter berdasarkan periode
        final todayAlarms = allAlarms.where((h) {
          return _toMs(h.timestamp) >= startOfTodayMs;
        }).toList();

        final last7DaysAlarms = allAlarms.where((h) {
          return _toMs(h.timestamp) >= startOf7DaysMs;
        }).toList();

        // Debug: log counts per periode
        debugPrint('[STATISTICS] Today alarms: ${todayAlarms.length}');
        debugPrint(
            '[STATISTICS] Last 7 days alarms: ${last7DaysAlarms.length}');
        debugPrint('[STATISTICS] All time alarms: ${allAlarms.length}');

        // Hitung statistik per periode
        final todayCounts = _countByStatus(todayAlarms);
        final weekCounts = _countByStatus(last7DaysAlarms);
        final allCounts = _countByStatus(allAlarms);

        // Debug: log final counts
        debugPrint(
          '[STATISTICS] TODAY: SAFE=${todayCounts['SAFE']}, '
          'NOISE=${todayCounts['NOISE']}, DANGER=${todayCounts['DANGER']}',
        );
        debugPrint(
          '[STATISTICS] WEEK: SAFE=${weekCounts['SAFE']}, '
          'NOISE=${weekCounts['NOISE']}, DANGER=${weekCounts['DANGER']}',
        );
        debugPrint(
          '[STATISTICS] ALL: SAFE=${allCounts['SAFE']}, '
          'NOISE=${allCounts['NOISE']}, DANGER=${allCounts['DANGER']}',
        );
        debugPrint(
          '[STATISTICS] Filtered system=${state.history.length - allAlarms.length}',
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ---- Statistik Hari Ini ----
            Text(
              'Statistik Hari Ini',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${todayAlarms.length} alarm hari ini',
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
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
                  title: 'Jumlah SAFE',
                  value: '${todayCounts['SAFE']}',
                  icon: Icons.check_circle,
                  color: AppColors.normal,
                ),
                StatisticCard(
                  title: 'Jumlah NOISE',
                  value: '${todayCounts['NOISE']}',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.noise,
                ),
                StatisticCard(
                  title: 'Jumlah DANGER',
                  value: '${todayCounts['DANGER']}',
                  icon: Icons.emergency,
                  color: AppColors.danger,
                ),
                StatisticCard(
                  title: 'Total Alarm',
                  value:
                      '${todayCounts['SAFE']! + todayCounts['NOISE']! + todayCounts['DANGER']!}',
                  icon: Icons.notifications_active,
                  color: AppColors.primary,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ---- Statistik 7 Hari ----
            Text(
              'Statistik 7 Hari Terakhir',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${last7DaysAlarms.length} alarm dalam 7 hari',
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
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
                  title: 'Jumlah SAFE',
                  value: '${weekCounts['SAFE']}',
                  icon: Icons.check_circle,
                  color: AppColors.normal,
                ),
                StatisticCard(
                  title: 'Jumlah NOISE',
                  value: '${weekCounts['NOISE']}',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.noise,
                ),
                StatisticCard(
                  title: 'Jumlah DANGER',
                  value: '${weekCounts['DANGER']}',
                  icon: Icons.emergency,
                  color: AppColors.danger,
                ),
                StatisticCard(
                  title: 'Total Alarm',
                  value:
                      '${weekCounts['SAFE']! + weekCounts['NOISE']! + weekCounts['DANGER']!}',
                  icon: Icons.notifications_active,
                  color: AppColors.primary,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ---- Statistik Semua Data ----
            Text(
              'Statistik Semua Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${allAlarms.length} alarm dari seluruh history',
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
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
                  title: 'Jumlah SAFE',
                  value: '${allCounts['SAFE']}',
                  icon: Icons.check_circle,
                  color: AppColors.normal,
                ),
                StatisticCard(
                  title: 'Jumlah NOISE',
                  value: '${allCounts['NOISE']}',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.noise,
                ),
                StatisticCard(
                  title: 'Jumlah DANGER',
                  value: '${allCounts['DANGER']}',
                  icon: Icons.emergency,
                  color: AppColors.danger,
                ),
                StatisticCard(
                  title: 'Total Alarm',
                  value:
                      '${allCounts['SAFE']! + allCounts['NOISE']! + allCounts['DANGER']!}',
                  icon: Icons.notifications_active,
                  color: AppColors.primary,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ---- Alarm Terbaru (hari ini) ----
            Text(
              'Alarm Terbaru',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if (todayAlarms.isEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'Belum ada alarm hari ini',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              )
            else
              ...todayAlarms.take(8).map(
                (item) {
                  final s = item.status.toString().toUpperCase().trim();
                  Color dotColor = AppColors.primary;
                  if (s == 'DANGER') dotColor = AppColors.danger;
                  if (s == 'NOISE') dotColor = AppColors.noise;
                  if (s == 'SAFE') dotColor = AppColors.normal;

                  return ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 10,
                      color: dotColor,
                    ),
                    title: Text(
                      s,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: dotColor,
                      ),
                    ),
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
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
