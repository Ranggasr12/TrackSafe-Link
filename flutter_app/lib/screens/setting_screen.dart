import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_stage.dart';
import '../utils/constants.dart';

/// Setting TAHAP 1 — preferensi UI lokal saja.
class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, AppStateProvider>(
      builder: (context, settings, appState, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Tampilan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _Card(
              children: [
                SwitchListTile(
                  secondary:
                      const Icon(Icons.dark_mode, color: AppColors.primary),
                  title: const Text('Dark Mode'),
                  value: settings.darkMode,
                  onChanged: settings.setDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Alarm & Notifikasi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.volume_up, color: AppColors.primary),
                  title: const Text('Volume Alarm'),
                  subtitle: Slider(
                    value: settings.alarmVolume,
                    onChanged: AppStage.alarmEnabled
                        ? settings.setAlarmVolume
                        : null,
                    min: 0,
                    max: 1,
                  ),
                  trailing: Text('${(settings.alarmVolume * 100).round()}%'),
                ),
                SwitchListTile(
                  secondary:
                      const Icon(Icons.vibration, color: AppColors.primary),
                  title: const Text('Vibration'),
                  value: settings.vibrationEnabled,
                  onChanged:
                      AppStage.alarmEnabled ? settings.setVibrationEnabled : null,
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_active,
                    color: AppColors.primary,
                  ),
                  title: const Text('Notification'),
                  value: settings.notificationEnabled,
                  onChanged: AppStage.alarmEnabled
                      ? settings.setNotificationEnabled
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Sistem',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.layers, color: AppColors.primary),
                  title: const Text('Development Stage'),
                  subtitle: Text('TAHAP ${appState.stage} / 11 — TrackSafe Link'),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('Aplikasi'),
                  subtitle: Text('${AppConstants.appName} v1.0.0'),
                ),
                const ListTile(
                  leading: Icon(Icons.link_off, color: AppColors.unknown),
                  title: Text('Backend URL'),
                  subtitle: Text('Not Configured'),
                ),
                const ListTile(
                  leading: Icon(Icons.cloud_off, color: AppColors.unknown),
                  title: Text('Firebase'),
                  subtitle: Text('Not Connected'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Sprint 11 aktif: local notification saat app di background.\n'
                'Notifikasi muncul saat status berubah ke NOISE, DANGER, atau OFFLINE.\n'
                'Toggle Notification di atas untuk mengaktifkan / menonaktifkan.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
