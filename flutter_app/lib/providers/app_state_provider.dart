import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/history_model.dart';
import '../models/monitoring_model.dart';
import '../repositories/monitoring_repository.dart';
import '../services/backend_status_service.dart';
import '../utils/app_stage.dart';
import '../utils/constants.dart';
import '../utils/system_labels.dart';

/// State UI sistem — Application Status dari /api/status + Firebase nyata.
class AppStateProvider extends ChangeNotifier {
  AppStateProvider({
    MonitoringRepository? repository,
    BackendStatusService? backendStatusService,
  })  : _repository = repository,
        _backendStatus = backendStatusService ?? BackendStatusService();

  MonitoringRepository? _repository;
  final BackendStatusService _backendStatus;

  Timer? _pollTimer;
  bool _disposed = false;
  bool _polling = false;

  String _applicationMode = SystemLabels.modeDevelopment;
  String _backendLabel = SystemLabels.backendChecking;
  String _firebaseLabel = SystemLabels.firebaseChecking;
  String _senderLabel = SystemLabels.senderWaiting;
  String _receiverLabel = SystemLabels.receiverWaiting;
  String _monitoringMessage = SystemLabels.monitoringWaiting;

  MonitoringModel _monitoring = MonitoringModel.noData();
  final List<HistoryModel> _history = [];

  bool _loading = false;

  String get applicationMode => _applicationMode;
  String get backendLabel => _backendLabel;
  String get firebaseLabel => _firebaseLabel;
  String get senderLabel => _senderLabel;
  String get receiverLabel => _receiverLabel;
  String get monitoringMessage => _monitoringMessage;

  MonitoringModel get monitoring => _monitoring;
  List<HistoryModel> get history => List.unmodifiable(_history);
  bool get isLoading => _loading;
  int get stage => AppStage.current;

  String get lastUpdateLabel =>
      _monitoring.hasData && _monitoring.timestamp > 0
          ? _monitoring.dateTime.toString()
          : SystemLabels.lastUpdateNone;

  String get batteryLabel =>
      _monitoring.battery == null
          ? SystemLabels.placeholder
          : '${_monitoring.battery}%';

  String get signalLabel =>
      _monitoring.signal == null
          ? SystemLabels.placeholder
          : '${_monitoring.signal}';

  bool get senderOnline => _senderLabel == SystemLabels.senderOnline;
  bool get receiverOnline => _receiverLabel == SystemLabels.receiverOnline;
  bool get backendOnline => _backendLabel == SystemLabels.backendOnline;
  bool get firebaseConnected =>
      _firebaseLabel == SystemLabels.firebaseConnected;

  /// Inject repository setelah dibuat di main (opsional).
  void attachRepository(MonitoringRepository repository) {
    _repository = repository;
  }

  /// Inisialisasi label awal, lalu mulai poll status nyata.
  Future<void> initStage1() async {
    _loading = true;
    notifyListeners();

    _applicationMode = AppStage.current >= 8
        ? SystemLabels.modeProduction
        : SystemLabels.modeDevelopment;
    _backendLabel = SystemLabels.backendChecking;
    _firebaseLabel = SystemLabels.firebaseChecking;
    _senderLabel = SystemLabels.senderWaiting;
    _receiverLabel = SystemLabels.receiverWaiting;
    _monitoringMessage = SystemLabels.monitoringWaiting;
    _monitoring = MonitoringModel.noData(
      deviceId: AppConstants.defaultDeviceId,
    );
    _history.clear();

    _loading = false;
    notifyListeners();

    await refreshSystemStatus();
    _startPolling();
  }

  /// Sinkronkan data monitoring + label Sender/Receiver dari Dashboard.
  void syncMonitoring({
    required MonitoringModel? monitoring,
    required String senderState,
    required String receiverState,
  }) {
    var changed = false;

    if (monitoring != null &&
        (monitoring.timestamp != _monitoring.timestamp ||
            monitoring.battery != _monitoring.battery ||
            monitoring.signal != _monitoring.signal ||
            monitoring.status != _monitoring.status ||
            monitoring.hasData != _monitoring.hasData)) {
      _monitoring = monitoring;
      changed = true;
    }

    if (_senderLabel != senderState) {
      _senderLabel = senderState;
      changed = true;
    }
    if (_receiverLabel != receiverState) {
      _receiverLabel = receiverState;
      changed = true;
    }

    final nextMessage = (monitoring != null &&
            monitoring.hasData &&
            senderState == SystemLabels.senderOnline)
        ? ''
        : SystemLabels.monitoringWaiting;
    if (_monitoringMessage != nextMessage) {
      _monitoringMessage = nextMessage;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> refreshSystemStatus() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      await Future.wait([
        _refreshBackendStatus(),
        _refreshFirebaseStatus(),
      ]);
    } finally {
      _polling = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConstants.statusPollIntervalSec),
      (_) {
        if (!_disposed) {
          refreshSystemStatus();
        }
      },
    );
  }

  /// Backend: GET /api/status (jika URL dikonfigurasi).
  /// Fallback: heartbeat Firebase `backend/status` dari ping backend.
  Future<void> _refreshBackendStatus() async {
    if (!AppStage.backendEnabled) {
      _setBackend(SystemLabels.backendNotConfigured);
      return;
    }

    final url = AppConstants.backendHealthUrl.trim();

    if (AppStage.backendHealthCheckEnabled && url.isNotEmpty) {
      final result = await _backendStatus.check(url);
      if (!result.configured) {
        _setBackend(SystemLabels.backendNotConfigured);
        return;
      }
      if (result.backendOnline) {
        _setBackend(SystemLabels.backendOnline);
        return;
      }
      _setBackend(SystemLabels.backendOffline);
      return;
    }

    // URL kosong — baca heartbeat yang ditulis backend saat /api/status & sensor.
    final heartbeatOnline = await _readBackendHeartbeat();
    if (heartbeatOnline == true) {
      _setBackend(SystemLabels.backendOnline);
      return;
    }
    if (heartbeatOnline == false) {
      _setBackend(SystemLabels.backendOffline);
      return;
    }
    // Gagal baca Firebase — tetap Checking, bukan "Not Configured".
    _setBackend(SystemLabels.backendChecking);
  }

  Future<void> _refreshFirebaseStatus() async {
    if (!AppStage.firebaseEnabled) {
      _setFirebase(SystemLabels.firebaseNotConnected);
      return;
    }

    try {
      final repo = _repository;
      if (repo != null && repo.isInitialized) {
        final connected = await repo.isConnected();
        _setFirebase(
          connected
              ? SystemLabels.firebaseConnected
              : SystemLabels.firebaseNotConnected,
        );
        return;
      }

      // Fallback langsung ke .info/connected jika repo belum siap.
      final snap = await FirebaseDatabase.instance
          .ref('.info/connected')
          .get()
          .timeout(const Duration(seconds: 5));
      final connected = snap.value == true;
      _setFirebase(
        connected
            ? SystemLabels.firebaseConnected
            : SystemLabels.firebaseNotConnected,
      );
    } catch (_) {
      _setFirebase(SystemLabels.firebaseNotConnected);
    }
  }

  /// Baca `backend/status` — diisi backend lewat pingFirebase / touchBackendHeartbeat.
  /// Returns null jika gagal baca; true/false jika berhasil parse.
  Future<bool?> _readBackendHeartbeat() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref(AppConstants.backendStatusPath)
          .get()
          .timeout(const Duration(seconds: 5));
      final value = snap.value;
      if (value is! Map) return false;

      final map = Map<dynamic, dynamic>.from(value);
      final online = map['online'] == true;
      final rawTs = map['timestamp'];
      int ts = 0;
      if (rawTs is int) {
        ts = rawTs;
      } else if (rawTs is double) {
        ts = rawTs.toInt();
      } else if (rawTs != null) {
        ts = int.tryParse(rawTs.toString()) ?? 0;
      }

      if (!online || ts <= 0) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final ageMs = now - ts;
      return ageMs <= AppConstants.backendHeartbeatFreshSec * 1000;
    } catch (_) {
      return null;
    }
  }

  void _setBackend(String label) {
    if (_backendLabel == label) return;
    _backendLabel = label;
    notifyListeners();
  }

  void _setFirebase(String label) {
    if (_firebaseLabel == label) return;
    _firebaseLabel = label;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _backendStatus.dispose();
    super.dispose();
  }
}
