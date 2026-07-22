import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/history_model.dart';
import '../models/monitoring_model.dart';
import '../repositories/monitoring_repository.dart';
import '../services/firebase_service.dart';
import '../utils/app_stage.dart';
import '../utils/constants.dart';
import '../utils/system_labels.dart';

/// State UI sistem — membaca status dari Firebase Realtime Database.
///
/// Sesuai arsitektur final:
/// - TIDAK polling HTTP ke backend
/// - TIDAK menggunakan HttpClient/BackendStatusService
/// - HANYA membaca dari Firebase RTDB
class AppStateProvider extends ChangeNotifier {
  AppStateProvider({
    MonitoringRepository? repository,
    FirebaseService? firebaseService,
  })  : _repository = repository,
        _firebaseService = firebaseService;

  MonitoringRepository? _repository;
  final FirebaseService? _firebaseService;

  StreamSubscription<List<HistoryModel>>? _historySubscription;
  StreamSubscription<Map<String, dynamic>>? _backendStatusSubscription;
  StreamSubscription<DatabaseEvent>? _firebaseConnectionSubscription;

  String _backendLabel = SystemLabels.backendChecking;
  String _firebaseLabel = SystemLabels.firebaseChecking;
  String _senderLabel = SystemLabels.senderWaiting;
  String _receiverLabel = SystemLabels.receiverWaiting;
  String _monitoringMessage = SystemLabels.monitoringWaiting;

  MonitoringModel _monitoring = MonitoringModel.noData();
  final List<HistoryModel> _history = [];

  bool _loading = false;

  String get backendLabel => _backendLabel;
  String get firebaseLabel => _firebaseLabel;
  String get senderLabel => _senderLabel;
  String get receiverLabel => _receiverLabel;
  String get monitoringMessage => _monitoringMessage;

  MonitoringModel get monitoring => _monitoring;
  List<HistoryModel> get history => List.unmodifiable(_history);
  bool get isLoading => _loading;

  String get lastUpdateLabel => _monitoring.hasData && _monitoring.timestamp > 0
      ? _monitoring.dateTime.toString()
      : SystemLabels.lastUpdateNone;

  String get batteryLabel => _monitoring.battery == null
      ? SystemLabels.placeholder
      : '${_monitoring.battery}%';

  String get signalLabel => _monitoring.signal == null
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

  /// Inisialisasi label awal, lalu mulai stream dari Firebase.
  Future<void> initStage1() async {
    _loading = true;
    notifyListeners();

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

    // Tunggu Firebase terinisialisasi sebelum cek status
    await _ensureFirebaseReady();
    await _refreshSystemStatus();
    _startBackendStream();
    _startFirebaseConnectionStream();
  }

  /// Pastikan FirebaseService sudah connect sebelum cek status.
  Future<void> _ensureFirebaseReady() async {
    final firebase = _firebaseService;
    if (firebase == null) return;

    try {
      if (!firebase.isInitialized) {
        await firebase.connect();
      }
      _setFirebase(SystemLabels.firebaseConnected);
      debugPrint('[AppStateProvider] Firebase ready');
    } catch (e) {
      debugPrint('[AppStateProvider] Firebase init error: $e');
      _setFirebase(SystemLabels.firebaseNotConnected);
    }
  }

  /// Mulai mendengarkan stream history dari Firebase.
  void startHistoryStream() {
    final firebase = _firebaseService;
    if (firebase == null || !firebase.isInitialized) return;

    _historySubscription?.cancel();
    try {
      _historySubscription = firebase.historyStream().listen(
        (items) {
          _history
            ..clear()
            ..addAll(items);

          // Debug: log data received from Firebase stream
          debugPrint(
              '[AppStateProvider] History stream: ${items.length} items');
          if (items.isNotEmpty) {
            for (int i = 0; i < (items.length < 3 ? items.length : 3); i++) {
              final item = items[i];
              debugPrint(
                '[AppStateProvider] History[$i]: '
                'status="${item.status}", '
                'eventType="${item.eventType}", '
                'timestamp=${item.timestamp}',
              );
            }
          }

          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('[AppStateProvider] history stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[AppStateProvider] startHistoryStream error: $e');
    }
  }

  /// Mulai stream .info/connected untuk memantau koneksi Firebase secara realtime.
  void _startFirebaseConnectionStream() {
    try {
      _firebaseConnectionSubscription?.cancel();
      _firebaseConnectionSubscription = FirebaseDatabase.instance
          .ref('.info/connected')
          .onValue
          .listen((DatabaseEvent event) {
        final connected = event.snapshot.value as bool? ?? false;
        _setFirebase(
          connected
              ? SystemLabels.firebaseConnected
              : SystemLabels.firebaseNotConnected,
        );
        debugPrint(
          '[AppStateProvider] Firebase connection: ${connected ? "CONNECTED" : "DISCONNECTED"}',
        );
      }, onError: (Object e) {
        debugPrint('[AppStateProvider] Firebase connection stream error: $e');
        _setFirebase(SystemLabels.firebaseNotConnected);
      });
    } catch (e) {
      debugPrint('[AppStateProvider] _startFirebaseConnectionStream error: $e');
      _setFirebase(SystemLabels.firebaseNotConnected);
    }
  }

  /// Mulai stream status backend dari Firebase (bukan polling HTTP).
  void _startBackendStream() {
    final firebase = _firebaseService;
    if (firebase == null || !firebase.isInitialized) return;

    _backendStatusSubscription?.cancel();
    try {
      _backendStatusSubscription = firebase.backendStatusStream().listen(
        (status) {
          if (status.isEmpty) {
            _setBackend(SystemLabels.backendOffline);
            return;
          }
          final online = status['online'] == true;
          _setBackend(
            online ? SystemLabels.backendOnline : SystemLabels.backendOffline,
          );
        },
        onError: (Object e) {
          debugPrint('[AppStateProvider] backend status stream error: $e');
          _setBackend(SystemLabels.backendOffline);
        },
      );
    } catch (e) {
      debugPrint('[AppStateProvider] _startBackendStream error: $e');
      _setBackend(SystemLabels.backendOffline);
    }
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

  Future<void> _refreshSystemStatus() async {
    try {
      await _refreshFirebaseStatus();
    } catch (_) {
      // Silent catch — stream akan handle update selanjutnya
    }
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
    _historySubscription?.cancel();
    _backendStatusSubscription?.cancel();
    _firebaseConnectionSubscription?.cancel();
    super.dispose();
  }
}
