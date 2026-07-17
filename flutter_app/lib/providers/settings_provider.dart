import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_stage.dart';
import '../utils/constants.dart';
import '../widgets/notification_listener_widget.dart';

/// Preferensi pengguna: volume, getar, notifikasi, dark mode.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider();

  double _alarmVolume = 1.0;
  bool _vibrationEnabled = true;
  bool _notificationEnabled = true;
  bool _darkMode = false;
  bool _loaded = false;

  double get alarmVolume => _alarmVolume;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get notificationEnabled => _notificationEnabled;
  bool get darkMode => _darkMode;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _alarmVolume = prefs.getDouble(AppConstants.prefAlarmVolume) ?? 1.0;
      _vibrationEnabled = prefs.getBool(AppConstants.prefVibration) ?? true;
      _notificationEnabled =
          prefs.getBool(AppConstants.prefNotification) ?? true;
      _darkMode = prefs.getBool(AppConstants.prefDarkMode) ?? false;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsProvider load error: $e');
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setAlarmVolume(double value) async {
    _alarmVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.prefAlarmVolume, _alarmVolume);
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefVibration, value);
  }

  Future<void> setNotificationEnabled(bool value) async {
    _notificationEnabled = value;
    notifyListeners();
    if (AppStage.localNotificationEnabled && value) {
      await requestNotificationPermissionIfNeeded(true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefNotification, value);
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefDarkMode, value);
  }
}
