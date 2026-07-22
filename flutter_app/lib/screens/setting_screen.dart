import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../providers/device_pairing_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_stage.dart';
import 'manage_devices_screen.dart';

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
                  leading:
                      const Icon(Icons.volume_up, color: AppColors.primary),
                  title: const Text('Volume Alarm'),
                  subtitle: Slider(
                    value: settings.alarmVolume,
                    onChanged:
                        AppStage.alarmEnabled ? settings.setAlarmVolume : null,
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
                  onChanged: AppStage.alarmEnabled
                      ? settings.setVibrationEnabled
                      : null,
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
              'Perangkat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _Card(
              children: [
                Consumer<DevicePairingProvider>(
                  builder: (context, pairing, _) {
                    return ListTile(
                      leading:
                          const Icon(Icons.devices, color: AppColors.primary),
                      title: const Text('Manage Devices'),
                      subtitle: Text(
                        pairing.isPaired
                            ? '${pairing.senderId} / ${pairing.receiverId}'
                            : 'Belum ada perangkat',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ManageDevicesScreen(),
                          ),
                        );
                      },
                    );
                  },
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
            _Card(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.cloud_outlined,
                    color: appState.backendOnline
                        ? AppColors.online
                        : AppColors.unknown,
                  ),
                  title: const Text('Backend Status'),
                  subtitle: Text(appState.backendLabel),
                ),
                ListTile(
                  leading: Icon(
                    Icons.storage_outlined,
                    color: appState.firebaseConnected
                        ? AppColors.online
                        : AppColors.unknown,
                  ),
                  title: const Text('Firebase'),
                  subtitle: Text(appState.firebaseLabel),
                ),
              ],
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
