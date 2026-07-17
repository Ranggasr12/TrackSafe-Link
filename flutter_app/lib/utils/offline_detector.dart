import '../models/monitoring_model.dart';
import 'constants.dart';

/// OfflineDetector — utility untuk menentukan apakah ESP32 offline.
///
/// Offline Detection dilakukan SEPENUHNYA di Flutter, bukan di Backend.
///
/// Backend hanya menyimpan timestamp terakhir ke Firebase.
/// Flutter menentukan status offline berdasarkan selisih waktu:
///   currentTime - lastDataTimestamp > threshold
///
/// OFFLINE bukan status dari ESP32.
/// OFFLINE adalah status aplikasi.
/// Status ESP32 (NORMAL/NOISE/DANGER) TIDAK diubah.
class OfflineDetector {
  OfflineDetector._();

  /// Threshold offline dalam milidetik (default 30 detik).
  static int get _thresholdMs => AppConstants.senderOfflineThresholdSec * 1000;

  /// Cek apakah data monitoring sudah stale (offline).
  ///
  /// Menggunakan [MonitoringModel.timestamp] sebagai acuan.
  /// Timestamp dari ESP32 dalam satuan **detik**,
  /// sehingga perlu dikonversi ke milidetik untuk perbandingan.
  ///
  /// Returns `true` jika selisih waktu > threshold (30 detik).
  static bool isOffline(MonitoringModel? monitoring) {
    if (monitoring == null) return true;
    if (!monitoring.hasData) return true;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dataTimeMs = monitoring.timestamp > 0
        ? (monitoring.timestamp < 1000000000000
            ? monitoring.timestamp * 1000 // detik → ms
            : monitoring.timestamp) // sudah dalam ms
        : 0;

    final diffMs = nowMs - dataTimeMs;
    return diffMs > _thresholdMs;
  }
}
