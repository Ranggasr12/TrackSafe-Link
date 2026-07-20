import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state_provider.dart';
import 'providers/device_pairing_provider.dart';
import 'providers/monitoring_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/monitoring_repository.dart';
import 'screens/main_shell.dart';
import 'services/firebase_service.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_stage.dart';
import 'utils/constants.dart';
import 'widgets/notification_listener_widget.dart';

/// TrackSafe Link — monitoring realtime + local notification (Sprint 11).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeDateFormatting('id_ID', null);

  final settings = SettingsProvider();
  await settings.load();

  if (AppStage.localNotificationEnabled) {
    await LocalNotificationService.instance.initialize();
    if (settings.notificationEnabled) {
      await LocalNotificationService.instance.requestPermission();
    }
  }

  final firebaseService = FirebaseService();
  final pairing = DevicePairingProvider(firebaseService: firebaseService);
  await pairing.load();

  final monitoringRepo = MonitoringRepository(firebaseService: firebaseService);
  final monitoringProvider = MonitoringProvider(repository: monitoringRepo);

  final appState = AppStateProvider(
    repository: monitoringRepo,
    firebaseService: firebaseService,
  );
  await appState.initStage1();
  // Start history stream after Firebase is initialized
  appState.startHistoryStream();

  debugPrint(
    'TrackSafe Link started — AppStage=${AppStage.current} '
    'paired=${pairing.isPaired}',
  );

  runApp(
    TrackSafeApp(
      settingsProvider: settings,
      appStateProvider: appState,
      monitoringProvider: monitoringProvider,
      devicePairingProvider: pairing,
    ),
  );
}

class TrackSafeApp extends StatelessWidget {
  const TrackSafeApp({
    super.key,
    required this.settingsProvider,
    required this.appStateProvider,
    required this.monitoringProvider,
    required this.devicePairingProvider,
  });

  final SettingsProvider settingsProvider;
  final AppStateProvider appStateProvider;
  final MonitoringProvider monitoringProvider;
  final DevicePairingProvider devicePairingProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: appStateProvider),
        ChangeNotifierProvider.value(value: monitoringProvider),
        ChangeNotifierProvider.value(value: devicePairingProvider),
      ],
      child: NotificationListenerWidget(
        child: Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
              home: const AppBootstrap(),
            );
          },
        ),
      ),
    );
  }
}
