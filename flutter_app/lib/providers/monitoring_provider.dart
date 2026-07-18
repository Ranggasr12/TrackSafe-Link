import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/monitoring_model.dart';
import '../repositories/monitoring_repository.dart';
import '../utils/constants.dart';
import '../utils/offline_detector.dart';

/// MonitoringProvider — penghubung antara UI dan MonitoringRepository.
///
/// Mengelola state monitoring dan menyediakan data ke layer UI.
/// Tidak mengandung business logic tingkat tinggi (alarm/notifikasi).
///
/// Provider bertanggung jawab menentukan:
/// - ONLINE / OFFLINE
/// - Status layar (NORMAL / NOISE / DANGER / UNKNOWN / OFFLINE)
/// - Nilai display untuk Battery, Signal, Distance
///
/// Arsitektur:
///   UI → MonitoringProvider → MonitoringRepository → FirebaseService → Firebase RTDB
///
/// State:
/// - [monitoring]      : data monitoring terakhir (nullable)
/// - [isLoading]       : status loading
/// - [errorMessage]    : pesan error jika terjadi kegagalan
/// - [isInitialized]   : apakah provider sudah di-initialize
///
/// Computed display properties (UI-friendly):
/// - [currentStatus]   : status final untuk StatusCard
/// - [displayBattery]  : nilai baterai (null = tampilkan --)
/// - [displaySignal]   : nilai sinyal (null = tampilkan --)
/// - [displayDistance] : nilai jarak (null = tampilkan --)
/// - [displaySubtitle] : teks subtitle monitoring
class MonitoringProvider extends ChangeNotifier {
  final MonitoringRepository _repository;

  MonitoringModel? _monitoring;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  StreamSubscription<MonitoringModel>? _streamSubscription;
  Timer? _offlineTimer;

  /// Interval re-evaluasi offline (UI + notifikasi background).
  static const Duration _offlineCheckInterval = Duration(seconds: 2);

  /// Provider membutuhkan [MonitoringRepository] yang sudah di-inject.
  MonitoringProvider({required MonitoringRepository repository})
      : _repository = repository;

  // --------------------------------------------------
  // GETTERS — Raw State
  // --------------------------------------------------

  /// Data monitoring terakhir.
  MonitoringModel? get monitoring => _monitoring;

  /// Status loading.
  bool get isLoading => _isLoading;

  /// Pesan error terakhir (null jika tidak ada error).
  String? get errorMessage => _errorMessage;

  /// Apakah provider sudah di-initialize.
  bool get isInitialized => _isInitialized;

  // --------------------------------------------------
  // GETTERS — Computed Display Properties
  // --------------------------------------------------

  /// Apakah data monitoring tersedia dan belum stale.
  bool get _hasValidData => _monitoring != null && _monitoring!.hasData;

  /// Apakah perangkat dalam keadaan offline (>10 detik tanpa data).
  bool get _isOffline =>
      _hasValidData && OfflineDetector.isOffline(_monitoring);

  /// Status final untuk ditampilkan di StatusCard.
  ///
  /// Logic:
  /// - OFFLINE jika data stale (>10 detik)
  /// - UNKNOWN jika belum ada data
  /// - NORMAL / NOISE / DANGER dari ESP32
  String get currentStatus {
    if (_isOffline) return SensorStatus.offline;
    if (_hasValidData) return _monitoring!.status;
    return SensorStatus.unknown;
  }

  /// Nilai baterai untuk ditampilkan (null = placeholder --).
  int? get displayBattery =>
      (_hasValidData && !_isOffline) ? _monitoring!.battery : null;

  /// Nilai sinyal untuk ditampilkan (null = placeholder --).
  int? get displaySignal =>
      (_hasValidData && !_isOffline) ? _monitoring!.signal : null;

  /// Nilai jarak untuk ditampilkan (null = placeholder --).
  int? get displayDistance =>
      (_hasValidData && !_isOffline) ? _monitoring!.distance : null;

  /// Teks subtitle monitoring.
  String get displaySubtitle {
    if (_isOffline) {
      return 'Data terakhir lebih dari '
          '${AppConstants.senderOfflineThresholdSec} detik. Menunggu ESP32.';
    }
    if (!_hasValidData) return 'Menunggu data ESP32.';
    return '';
  }

  // --------------------------------------------------
  // PUBLIC METHODS
  // --------------------------------------------------

  /// Inisialisasi provider.
  ///
  /// 1. connect() ke MonitoringRepository (Firebase)
  /// 2. subscribe monitoringStream()
  /// 3. update state setiap ada data baru
  ///
  /// Aman dipanggil berkali-kali (hanya akan execute sekali).
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.connect();

      _streamSubscription = _repository.monitoringStream().listen(
            _onMonitoringData,
            onError: _onError,
            onDone: _onDone,
            cancelOnError: false,
          );

      _isInitialized = true;
      _isLoading = false;
      _startOfflineTimer();
      notifyListeners();

      debugPrint('[MonitoringProvider] Initialized');
    } catch (error) {
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();

      debugPrint('[MonitoringProvider] Initialize failed: $error');
    }
  }

  /// Sinkronisasi ulang data monitoring.
  ///
  /// Selalu membuat subscription baru agar path Firebase mengikuti
  /// Device ID aktif hasil Device Pairing (Ganti Device), tanpa mengubah
  /// logika status / display.
  Future<void> refresh() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _streamSubscription?.cancel();
      _streamSubscription = null;

      _streamSubscription = _repository.monitoringStream().listen(
            _onMonitoringData,
            onError: _onError,
            onDone: _onDone,
            cancelOnError: false,
          );

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  /// Dispose provider — bersihkan seluruh subscription.
  ///
  /// Panggil saat provider tidak lagi digunakan untuk
  /// mencegah memory leak.
  @override
  void dispose() {
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _monitoring = null;
    _isInitialized = false;
    _isLoading = false;
    _errorMessage = null;
    super.dispose();
  }

  // --------------------------------------------------
  // PRIVATE HELPERS
  // --------------------------------------------------

  /// Handler ketika ada data monitoring baru dari stream.
  void _onMonitoringData(MonitoringModel data) {
    _monitoring = data;
    _errorMessage = null;
    notifyListeners();
  }

  /// Handler ketika stream mengalami error.
  void _onError(Object error) {
    _errorMessage = error.toString();
    notifyListeners();

    debugPrint('[MonitoringProvider] Stream error: $error');
  }

  /// Handler ketika stream selesai (done).
  void _onDone() {
    debugPrint('[MonitoringProvider] Stream done');
  }

  /// Timer periodik agar status OFFLINE ter-update tanpa event Firebase baru.
  void _startOfflineTimer() {
    _offlineTimer?.cancel();
    _offlineTimer = Timer.periodic(_offlineCheckInterval, (_) {
      if (!_isInitialized) return;
      notifyListeners();
    });
  }
}
