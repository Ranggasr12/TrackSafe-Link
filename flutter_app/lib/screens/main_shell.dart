import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_pairing_provider.dart';
import 'dashboard_screen.dart';
import 'device_pairing_screen.dart';
import 'history_screen.dart';
import 'setting_screen.dart';
import 'splash_screen.dart';
import 'statistics_screen.dart';

/// Splash → cek Device Pairing → Dashboard / Pairing Screen.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(
        onFinished: () {
          if (mounted) setState(() => _splashDone = true);
        },
      );
    }

    return Consumer<DevicePairingProvider>(
      builder: (context, pairing, _) {
        if (!pairing.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!pairing.isPaired) {
          return DevicePairingScreen(
            onPaired: () {
              pairing.touchLastConnected();
            },
          );
        }

        return const MainShell();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'History', 'Statistik', 'Pengaturan'];

  static const _pages = [
    DashboardScreen(),
    HistoryScreen(),
    StatisticsScreen(),
    SettingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DevicePairingProvider>().touchLastConnected();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
      ),
    );
  }
}
