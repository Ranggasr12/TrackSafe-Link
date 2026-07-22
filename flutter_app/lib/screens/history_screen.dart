import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/history_model.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_colors.dart';

/// History — realtime dari Firebase `history/`.
/// Hanya menampilkan alarm Rule Base: SAFE, NOISE, DANGER.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  /// Filter: hanya tampilkan alarm Rule Base (SAFE, NOISE, DANGER).
  /// eventType BUKAN event sistem.
  /// Abaikan event sistem seperti BACKEND_RESTART, PAIR, ONLINE, OFFLINE, dll.
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
      // Status hanya SAFE, NOISE, DANGER
      final s = item.status.toString().toUpperCase().trim();
      if (s != 'SAFE' && s != 'NOISE' && s != 'DANGER') return false;

      // eventType — jika merupakan event sistem, buang
      final et = item.eventType.toString().toUpperCase().trim();
      if (systemEvents.contains(et)) return false;

      // eventType null, kosong, atau bukan sistem — izinkan
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, state, _) {
        final allItems = state.history;
        final items = filterAlarmOnly(allItems);

        // Debug: log for comparison with StatisticsScreen
        debugPrint('[HISTORY] Total history: ${allItems.length}');
        debugPrint('[HISTORY] After filterAlarmOnly: ${items.length}');
        if (items.isNotEmpty) {
          for (int i = 0; i < (items.length < 5 ? items.length : 5); i++) {
            final item = items[i];
            debugPrint(
              '[HISTORY] Item[$i]: status=${item.status}, eventType=${item.eventType}, '
              'timestamp=${item.timestamp}',
            );
          }
        } else if (allItems.isNotEmpty) {
          for (int i = 0;
              i < (allItems.length < 5 ? allItems.length : 5);
              i++) {
            final item = allItems[i];
            debugPrint(
              '[HISTORY] RAW Item[$i]: status=${item.status}, eventType=${item.eventType}, '
              'timestamp=${item.timestamp}',
            );
          }
        }

        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Riwayat Alarm Kosong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hanya menampilkan status SAFE, NOISE, dan DANGER.\n'
                    'Event sistem tidak ditampilkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return _HistoryTile(item: item);
          },
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final HistoryModel item;

  Color _eventColor() {
    final s = item.status.toString().toUpperCase().trim();
    if (s == 'DANGER') return AppColors.danger;
    if (s == 'NOISE') return AppColors.noise;
    if (s == 'SAFE') return AppColors.normal;
    return AppColors.primary;
  }

  IconData _eventIcon() {
    final s = item.status.toString().toUpperCase().trim();
    if (s == 'DANGER') return Icons.emergency;
    if (s == 'NOISE') return Icons.warning_amber_rounded;
    if (s == 'SAFE') return Icons.check_circle;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _eventColor();
    final statusLabel = item.status.toString().toUpperCase().trim();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(_eventIcon(), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description.isNotEmpty
                        ? item.description
                        : '${item.deviceId} — $statusLabel',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (item.targetDeviceId != null &&
                      item.targetDeviceId!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${item.targetDeviceId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetaChip(
                        icon: Icons.schedule,
                        label: '${item.dateLabel} ${item.timeLabel}',
                      ),
                      if (item.battery != null)
                        _MetaChip(
                          icon: Icons.battery_std,
                          label: '${item.battery}%',
                        ),
                      if (item.signal != null)
                        _MetaChip(
                          icon: Icons.signal_cellular_alt,
                          label: '${item.signal}',
                        ),
                      if (item.distance > 0)
                        _MetaChip(
                          icon: Icons.straighten,
                          label: '${item.distance} cm',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).hintColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
      ],
    );
  }
}
