import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/monitoring_model.dart';
import '../services/firebase_service.dart';

class MonitoringRepository {
  final FirebaseService _firebaseService;

  MonitoringModel? _cachedMonitoring;
  StreamSubscription<MonitoringModel>? _monitoringSubscription;

  /// Repository membutuhkan [FirebaseService] yang sudah di-inject.
  MonitoringRepository({required FirebaseService firebaseService})
      : _firebaseService = firebaseService;

  /// Apakah Firebase sudah terkoneksi.
  bool get isInitialized => _firebaseService.isInitialized;

  /// Data monitoring terakhir yang diterima (cache).
  MonitoringModel? get cachedMonitoring => _cachedMonitoring;

  /// Inisialisasi koneksi Firebase melalui service.
  ///
  /// Panggil sekali di awal aplikasi.
  /// Aman dipanggil berkali-kali.
  Future<void> connect() async {
    try {
      await _firebaseService.connect();
      debugPrint('[MonitoringRepository] Connected');
    } catch (error) {
      debugPrint('[MonitoringRepository] Connect failed: $error');
      rethrow;
    }
  }

  /// Stream data monitoring secara realtime.
  ///
  /// Mendengarkan perubahan dari FirebaseService dan
  /// menyimpan data terakhir ke cache internal.
  Stream<MonitoringModel> monitoringStream() {
    _ensureConnected();

    return _firebaseService.monitoringStream().map((monitoring) {
      _cachedMonitoring = monitoring;
      return monitoring;
    });
  }

  Future<MonitoringModel> getCurrentMonitoring() async {
    _ensureConnected();

    try {
      final completer = Completer<MonitoringModel>();
      final subscription = _firebaseService.monitoringStream().listen(
        (monitoring) {
          if (!completer.isCompleted) {
            _cachedMonitoring = monitoring;
            completer.complete(monitoring);
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) {
            debugPrint(
              '[MonitoringRepository] getCurrentMonitoring error: $error',
            );
            completer.complete(
              _cachedMonitoring ?? MonitoringModel.noData(),
            );
          }
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          subscription.cancel();
          return _cachedMonitoring ?? MonitoringModel.noData();
        },
      );

      await subscription.cancel();
      return result;
    } catch (error) {
      debugPrint('[MonitoringRepository] getCurrentMonitoring error: $error');
      return _cachedMonitoring ?? MonitoringModel.noData();
    }
  }

  /// Cek status koneksi Firebase.
  Future<bool> isConnected() async {
    try {
      return await _firebaseService.isConnected();
    } catch (error) {
      debugPrint('[MonitoringRepository] isConnected error: $error');
      return false;
    }
  }

  /// Guard: lempar StateError jika Firebase belum di-init.
  void _ensureConnected() {
    if (!_firebaseService.isInitialized) {
      throw StateError(
        '[MonitoringRepository] Firebase belum terkoneksi. '
        'Panggil connect() terlebih dahulu.',
      );
    }
  }

  /// Dispose subscription untuk mencegah memory leak.
  void dispose() {
    _monitoringSubscription?.cancel();
    _monitoringSubscription = null;
    _cachedMonitoring = null;
  }
}
