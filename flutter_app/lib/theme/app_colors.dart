/// Warna branding TrackSafe Link — Material 3 industrial palette.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryDark = Color(0xFF002171);
  static const Color secondary = Color(0xFF1565C0);

  // Sensor status (dari ESP32 / overlay lokal)
  static const Color normal = Color(0xFF2E7D32);
  static const Color normalSoft = Color(0xFFE8F5E9);
  static const Color noise = Color(0xFFF9A825);
  static const Color noiseSoft = Color(0xFFFFF8E1);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerSoft = Color(0xFFFFEBEE);
  static const Color acknowledged = Color(0xFF546E7A);
  static const Color unknown = Color(0xFF78909C);
  static const Color unknownSoft = Color(0xFFECEFF1);
  static const Color offlineSoft = Color(0xFFFFEBEE);

  // Surfaces
  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121820);
  static const Color cardDark = Color(0xFF1C2430);

  // Text
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF607080);
  static const Color textOnDark = Color(0xFFF5F7FA);

  // Connection / Application Status indicators
  static const Color online = Color(0xFF43A047);
  static const Color offline = Color(0xFFE53935);
  static const Color warning = Color(0xFFF9A825);
  static const Color neutral = Color(0xFF9E9E9E);
}
