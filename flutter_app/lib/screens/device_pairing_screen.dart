import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_pairing_provider.dart';
import '../providers/monitoring_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

/// Layar registrasi perangkat (Device Pairing).
class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({
    super.key,
    this.onPaired,
    this.allowBack = false,
  });

  /// Dipanggil setelah pair sukses (sebelum navigasi parent).
  final VoidCallback? onPaired;

  /// True jika dibuka dari Manage Devices (Ganti Device).
  final bool allowBack;

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _senderController = TextEditingController();
  final _receiverController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final pairing = context.read<DevicePairingProvider>();
    _senderController.text = pairing.senderId ?? '';
    _receiverController.text = pairing.receiverId ?? '';
  }

  @override
  void dispose() {
    _senderController.dispose();
    _receiverController.dispose();
    super.dispose();
  }

  Future<void> _onHubungkan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pairing = context.read<DevicePairingProvider>();
    final result = await pairing.pair(
      senderId: _senderController.text,
      receiverId: _receiverController.text,
    );

    if (!mounted) return;

    if (result == DevicePairResult.success) {
      // Re-subscribe monitoring ke Sender ID baru tanpa ubah business logic.
      final mon = context.read<MonitoringProvider>();
      if (mon.isInitialized) {
        await mon.refresh();
      }

      if (!mounted) return;
      widget.onPaired?.call();
      if (widget.allowBack && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    final message = switch (result) {
      DevicePairResult.senderNotFound ||
      DevicePairResult.receiverNotFound =>
        'Device tidak ditemukan',
      DevicePairResult.invalidInput =>
        pairing.errorMessage ?? 'Sender ID dan Receiver ID wajib diisi',
      DevicePairResult.error =>
        pairing.errorMessage ?? 'Gagal menghubungkan perangkat',
      DevicePairResult.success => '',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.allowBack
          ? AppBar(
              title: const Text('Ganti Device'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Consumer<DevicePairingProvider>(
          builder: (context, pairing, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                Center(
                  child: Icon(
                    Icons.link,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tambah Perangkat',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _senderController,
                        enabled: !pairing.isBusy,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Sender ID',
                          hintText: 'Contoh: sender01',
                          prefixIcon: Icon(Icons.sensors),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Sender ID wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _receiverController,
                        enabled: !pairing.isBusy,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!pairing.isBusy) _onHubungkan();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Receiver ID',
                          hintText: 'Contoh: receiver01',
                          prefixIcon: Icon(Icons.router),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Receiver ID wajib diisi';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: pairing.isBusy ? null : _onHubungkan,
                  icon: pairing.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    pairing.isBusy ? 'Menghubungkan...' : 'HUBUNGKAN',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.devices, size: 16, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Text(
                      'Validasi ke Firebase devices/{id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code, size: 16, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Text(
                      'QR Pairing — segera hadir',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
