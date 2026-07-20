import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../providers/device_pairing_provider.dart';
import '../providers/monitoring_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/system_labels.dart';
import 'device_pairing_screen.dart';

/// Kelola perangkat yang sudah di-pair.
class ManageDevicesScreen extends StatelessWidget {
  const ManageDevicesScreen({super.key});

  Future<void> _gantiDevice(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const DevicePairingScreen(allowBack: true),
      ),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perangkat berhasil diganti')),
      );
    }
  }

  Future<void> _hapusDevice(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Device'),
        content: const Text(
          'Pairing akan dihapus dari backend dan perangkat ini. '
          'Anda harus mendaftarkan perangkat lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await context.read<DevicePairingProvider>().clearPairing();
    // AppBootstrap mendeteksi !isPaired dan menampilkan DevicePairingScreen.
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Devices'),
      ),
      body: Consumer3<DevicePairingProvider, AppStateProvider,
          MonitoringProvider>(
        builder: (context, pairing, appState, mon, _) {
          final lastConnected = pairing.lastConnectedMs;
          final lastLabel = (lastConnected != null && lastConnected > 0)
              ? Formatters.dateTime(lastConnected)
              : SystemLabels.placeholder;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.devices,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Perangkat Terhubung',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoTile(
                        icon: Icons.sensors,
                        label: 'Sender ID',
                        value: pairing.senderId ?? SystemLabels.placeholder,
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.router,
                        label: 'Receiver ID',
                        value: pairing.receiverId ?? SystemLabels.placeholder,
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.sync,
                        label: 'Status',
                        value:
                            '${appState.senderLabel} / ${appState.receiverLabel}',
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.schedule,
                        label: 'Last Connected',
                        value: lastLabel,
                      ),
                      if (mon.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          mon.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _gantiDevice(context),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Ganti Device'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _hapusDevice(context),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text(
                  'Hapus Device',
                  style: TextStyle(color: AppColors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.danger),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
