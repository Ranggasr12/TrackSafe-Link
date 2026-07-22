import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'constants.dart';

/// Visual helper status monitoring (UNKNOWN / NORMAL / NOISE / DANGER / OFFLINE).
class StatusHelper {
  StatusHelper._();

  static Color color(String status) {
    switch (status.toUpperCase()) {
      case SensorStatus.danger:
        return AppColors.danger;
      case SensorStatus.noise:
        return AppColors.noise;
      case SensorStatus.normal:
      case SensorStatus.safe:
        return AppColors.normal;
      case SensorStatus.offline:
        return AppColors.offline;
      case SensorStatus.unknown:
      default:
        return AppColors.unknown;
    }
  }

  static Color softColor(String status) {
    switch (status.toUpperCase()) {
      case SensorStatus.danger:
        return AppColors.dangerSoft;
      case SensorStatus.noise:
        return AppColors.noiseSoft;
      case SensorStatus.normal:
      case SensorStatus.safe:
        return AppColors.normalSoft;
      case SensorStatus.offline:
        return AppColors.offlineSoft;
      case SensorStatus.unknown:
      default:
        return AppColors.unknownSoft;
    }
  }

  static IconData icon(String status) {
    switch (status.toUpperCase()) {
      case SensorStatus.danger:
        return Icons.emergency;
      case SensorStatus.noise:
        return Icons.warning_amber_rounded;
      case SensorStatus.normal:
      case SensorStatus.safe:
        return Icons.check_circle;
      case SensorStatus.offline:
        return Icons.cloud_off;
      case SensorStatus.unknown:
      default:
        return Icons.help_outline;
    }
  }

  static String title(String status) {
    switch (status.toUpperCase()) {
      case SensorStatus.danger:
        return 'KERETA TERDETEKSI';
      case SensorStatus.noise:
        return 'NOISE TERDETEKSI';
      case SensorStatus.normal:
      case SensorStatus.safe:
        return 'AMAN';
      case SensorStatus.offline:
        return 'SENDER OFFLINE';
      case SensorStatus.unknown:
      default:
        return 'MENUNGGU DATA';
    }
  }

  static String subtitle(String status) {
    switch (status.toUpperCase()) {
      case SensorStatus.danger:
        return 'SEGERA MENJAUH DARI REL';
      case SensorStatus.noise:
        return 'Sedang memverifikasi kondisi.';
      case SensorStatus.normal:
      case SensorStatus.safe:
        return 'Tidak ada kereta.';
      case SensorStatus.offline:
        return 'Data terakhir sudah lebih dari 15 detik. Menunggu ESP32.';
      case SensorStatus.unknown:
      default:
        return 'ESP32 belum pernah mengirim data ke Firebase.';
    }
  }

  static String label(String status) => status.toUpperCase();
}
