import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/monitoring_model.dart';
import '../services/backend_api_service.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';

/// Hasil validasi / pair perangkat.
enum DevicePairResult {
  success,
  senderNotFound,
  receiverNotFound,
  invalidInput,
  error,
}

/// Device Pairing — Backend API + SharedPreferences + Firebase monitoring.
///
/// Pairing dilakukan melalui Backend API (POST /api/device/pair).
/// Data monitoring dibaca langsung dari Firebase RTDB.
class DevicePairingProvider extends ChangeNotifier {
  DevicePairingProvider({
    required FirebaseService firebaseService,
    BackendApiService? backendApi,
  })  : _firebase = firebaseService,
        _backendApi = backendApi ?? BackendApiService();

  final FirebaseService _firebase;
  final BackendApiService _backendApi;

  String? _senderId;
  String? _receiverId;
  int? _lastConnectedMs;
  bool _loaded = false;
  bool _busy = false;
  String? _errorMessage;

  MonitoringModel? _receiverTelemetry;
  StreamSubscription<MonitoringModel>? _receiverSub;

  String? get senderId => _senderId;
  String? get receiverId => _receiverId;
  int? get lastConnectedMs => _lastConnectedMs;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  bool get isPaired =>
      (_senderId?.trim().isNotEmpty ?? false) &&
      (_receiverId?.trim().isNotEmpty ?? false);
  String? get errorMessage => _errorMessage;
  MonitoringModel? get receiverTelemetry => _receiverTelemetry;

  /// Muat pasangan perangkat dari SharedPreferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _senderId = prefs.getString(AppConstants.prefSenderId)?.trim();
      _receiverId = prefs.getString(AppConstants.prefReceiverId)?.trim();
      _lastConnectedMs = prefs.getInt(AppConstants.prefLastConnectedMs);

      // Migrasi ringan: prefDeviceId lama → sender jika belum ada pair.
      final legacy = prefs.getString(AppConstants.prefDeviceId)?.trim();
      if ((_senderId == null || _senderId!.isEmpty) &&
          legacy != null &&
          legacy.isNotEmpty) {
        _senderId = legacy;
      }

      if (isPaired) {
        await _syncPairingFromBackend();
        _firebase.setActiveDeviceId(_senderId!);
        await _ensureFirebase();
        _watchReceiver(_receiverId!);
      }

      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[DevicePairingProvider] load error: $e');
      _loaded = true;
      notifyListeners();
    }
  }

  /// Validasi melalui Backend API lalu simpan pair.
  Future<DevicePairResult> pair({
    required String senderId,
    required String receiverId,
  }) async {
    final sender = senderId.trim();
    final receiver = receiverId.trim();

    if (sender.isEmpty || receiver.isEmpty) {
      _errorMessage = 'Sender ID dan Receiver ID wajib diisi';
      notifyListeners();
      return DevicePairResult.invalidInput;
    }

    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureFirebase();

      // Step 1: Cek apakah device ada di Firebase
      final senderOk = await _firebase.deviceExists(sender);
      if (!senderOk) {
        _busy = false;
        _errorMessage = 'Device tidak ditemukan';
        notifyListeners();
        return DevicePairResult.senderNotFound;
      }

      final receiverOk = await _firebase.deviceExists(receiver);
      if (!receiverOk) {
        _busy = false;
        _errorMessage = 'Device tidak ditemukan';
        notifyListeners();
        return DevicePairResult.receiverNotFound;
      }

      // Step 2: Panggil Backend API untuk pairing (source of truth)
      final pairResult = await _backendApi.pairDevices(
        senderId: sender,
        receiverId: receiver,
      );
      if (!pairResult) {
        _busy = false;
        _errorMessage = 'Gagal pairing melalui backend';
        notifyListeners();
        return DevicePairResult.error;
      }

      // Step 3: Simpan ke SharedPreferences
      final now = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefSenderId, sender);
      await prefs.setString(AppConstants.prefReceiverId, receiver);
      await prefs.setInt(AppConstants.prefLastConnectedMs, now);
      // Sinkronkan pref lama agar komponen legacy tetap konsisten.
      await prefs.setString(AppConstants.prefDeviceId, sender);

      _senderId = sender;
      _receiverId = receiver;
      _lastConnectedMs = now;
      _firebase.setActiveDeviceId(sender);
      _watchReceiver(receiver);

      _busy = false;
      notifyListeners();
      return DevicePairResult.success;
    } catch (e) {
      debugPrint('[DevicePairingProvider] pair error: $e');
      _busy = false;
      _errorMessage = e.toString();
      notifyListeners();
      return DevicePairResult.error;
    }
  }

  /// Hapus pair → backend unpair + clear local prefs.
  Future<void> clearPairing() async {
    final sender = _senderId;
    final receiver = _receiverId;

    if (sender != null || receiver != null) {
      await _backendApi.unpairDevices(
        senderId: sender,
        receiverId: receiver,
      );
    }

    await _receiverSub?.cancel();
    _receiverSub = null;
    _receiverTelemetry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefSenderId);
    await prefs.remove(AppConstants.prefReceiverId);
    await prefs.remove(AppConstants.prefLastConnectedMs);
    await prefs.remove(AppConstants.prefDeviceId);

    _senderId = null;
    _receiverId = null;
    _lastConnectedMs = null;
    _firebase.clearActiveDeviceId();
    notifyListeners();
  }

  /// Perbarui timestamp last connected (saat masuk dashboard).
  Future<void> touchLastConnected() async {
    if (!isPaired) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastConnectedMs = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefLastConnectedMs, now);
    notifyListeners();
  }

  Future<void> _syncPairingFromBackend() async {
    final sender = _senderId?.trim();
    if (sender == null || sender.isEmpty) return;

    final info = await _backendApi.getPairing(sender);
    if (info == null || info['paired'] != true) return;

    final pairedId = info['pairedDeviceId']?.toString();
    if (pairedId == null || pairedId.isEmpty) return;

    _receiverId = pairedId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefReceiverId, pairedId);
    notifyListeners();
  }

  Future<void> _ensureFirebase() async {
    if (!_firebase.isInitialized) {
      await _firebase.connect();
    }
  }

  void _watchReceiver(String receiverId) {
    _receiverSub?.cancel();
    _receiverSub = null;
    _receiverTelemetry = null;

    try {
      _receiverSub = _firebase.deviceStream(receiverId).listen(
        (model) {
          _receiverTelemetry = model;
          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('[DevicePairingProvider] receiver stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[DevicePairingProvider] watchReceiver failed: $e');
    }
  }

  @override
  void dispose() {
    _receiverSub?.cancel();
    _receiverSub = null;
    _backendApi.dispose();
    super.dispose();
  }
}
