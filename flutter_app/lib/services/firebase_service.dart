import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_database/firebase_database.dart';

import '../models/monitoring_model.dart';
import '../models/history_model.dart';
import '../models/pairing_model.dart';
import '../utils/constants.dart';

/// FirebaseService — read-only layer untuk Firebase Realtime Database.
///
/// Sesuai arsitektur final TrackSafe:
/// 1. Flutter TIDAK connect MQTT
/// 2. Flutter TIDAK publish/subscribe MQTT
/// 3. Flutter TIDAK polling backend
/// 4. Flutter HANYA membaca Firebase RTDB
///
/// Method:
/// - connect()                    : inisialisasi koneksi Firebase
/// - monitoringStream()           : stream data device (sender) live
/// - deviceStream()               : stream data device arbitrary (receiver)
/// - historyStream()              : stream daftar riwayat
/// - pairingStream()              : stream data pairing
/// - devicesListStream()          : stream daftar devices
/// - backendStatusStream()        : stream status backend
/// - isConnected()                : cek status koneksi Firebase
/// - deviceExists()               : cek apakah device ada di Firebase (read only)
class FirebaseService {
  FirebaseDatabase? _database;
  bool _initialized = false;
  bool _connecting = false;

  /// Device ID aktif dari Device Pairing (bukan hardcoded).
  String? _activeDeviceId;

  /// Apakah Firebase sudah di-initialize.
  bool get isInitialized => _initialized;

  /// Device ID yang sedang dimonitor (Sender hasil pairing).
  String? get activeDeviceId => _activeDeviceId;

  /// Set Device ID aktif setelah pairing berhasil.
  void setActiveDeviceId(String deviceId) {
    final trimmed = deviceId.trim();
    _activeDeviceId = trimmed.isEmpty ? null : trimmed;
  }

  /// Hapus Device ID aktif (setelah unpair).
  void clearActiveDeviceId() {
    _activeDeviceId = null;
  }

  /// Inisialisasi koneksi Firebase.
  Future<void> connect() async {
    if (_initialized) return;
    if (_connecting) {
      await _waitForInit();
      return;
    }
    _connecting = true;

    try {
      if (Firebase.apps.isEmpty) {
        throw StateError(
          'Firebase belum diinisialisasi. Pastikan Firebase.initializeApp() dipanggil di main.dart sebelum FirebaseService.connect().',
        );
      }
      _database = FirebaseDatabase.instance;
      _initialized = true;
      debugPrint('[FirebaseService] Initialized successfully');
    } catch (error) {
      _initialized = false;
      _database = null;
      debugPrint('[FirebaseService] Init failed: $error');
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  /// Tunggu hingga proses koneksi selesai (jika sedang connect).
  Future<void> _waitForInit() async {
    while (_connecting) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Reference ke node device aktif (Sender dari Device Pairing).
  DatabaseReference _deviceRef() {
    _guardInitialized();
    final deviceId = _resolveActiveDeviceId();
    return _database!.ref('${AppConstants.devicesPath}/$deviceId');
  }

  String _resolveActiveDeviceId() {
    final active = _activeDeviceId?.trim();
    if (active != null && active.isNotEmpty) return active;
    throw StateError(
      '[FirebaseService] Device ID belum di-pair. '
      'Lakukan Device Pairing terlebih dahulu.',
    );
  }

  DatabaseReference _deviceRefFor(String deviceId) {
    _guardInitialized();
    final id = deviceId.trim();
    if (id.isEmpty) {
      throw ArgumentError('deviceId tidak boleh kosong');
    }
    return _database!.ref('${AppConstants.devicesPath}/$id');
  }

  /// Reference ke node history.
  DatabaseReference _historyRef() {
    _guardInitialized();
    return _database!.ref(AppConstants.historyPath);
  }

  /// Reference ke node pairings.
  DatabaseReference _pairingsRef() {
    _guardInitialized();
    return _database!.ref('pairings');
  }

  /// Reference ke node backend/status.
  DatabaseReference _backendStatusRef() {
    _guardInitialized();
    return _database!.ref('backend/status');
  }

  /// Reference ke node .info/connected (built-in Firebase).
  DatabaseReference _infoConnectedRef() {
    _guardInitialized();
    return _database!.ref('.info/connected');
  }

  /// Guard: lempar StateError jika Firebase belum di-init.
  void _guardInitialized() {
    if (!_initialized || _database == null) {
      throw StateError(
        '[FirebaseService] Belum di-initialized. Panggil connect() terlebih dahulu.',
      );
    }
  }

  // --------------------------------------------------
  // PARSER HELPERS
  // --------------------------------------------------

  /// Parse snapshot value menjadi Map? (null-safe).
  Map<dynamic, dynamic>? _toMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<dynamic, dynamic>) return value;
    if (value is Map) return Map<dynamic, dynamic>.from(value);
    return null;
  }

  // --------------------------------------------------
  // PUBLIC STREAMS — READ ONLY
  // --------------------------------------------------

  /// Stream data monitoring device secara realtime.
  ///
  /// Membaca dari `devices/{deviceId}` (Sender hasil pairing).
  /// Data: status, distance, battery, signal, gps, deviceType,
  ///       lastSeen, linkStatus, pairedReceiver, limitSwitch
  Stream<MonitoringModel> monitoringStream() {
    _guardInitialized();
    final deviceId = _resolveActiveDeviceId();

    return _deviceRef().onValue.map((DatabaseEvent event) {
      try {
        final data = _toMap(event.snapshot.value);

        if (data == null || data.isEmpty) {
          return MonitoringModel.noData(deviceId: deviceId);
        }

        return MonitoringModel.fromMap(data);
      } catch (error) {
        debugPrint('[FirebaseService] monitoringStream parse error: $error');
        return MonitoringModel.noData(deviceId: deviceId);
      }
    });
  }

  /// Cek apakah node `devices/{deviceId}` ada di Firebase (read only).
  Future<bool> deviceExists(String deviceId) async {
    _guardInitialized();
    final id = deviceId.trim();
    if (id.isEmpty) return false;

    try {
      final snap = await _deviceRefFor(id).get().timeout(
            const Duration(seconds: 8),
          );
      if (!snap.exists) return false;
      final value = snap.value;
      if (value == null) return false;
      if (value is Map && value.isEmpty) return false;
      return true;
    } catch (error) {
      debugPrint('[FirebaseService] deviceExists($id) error: $error');
      rethrow;
    }
  }

  /// Stream telemetry perangkat arbitrary (mis. Receiver hasil pairing).
  /// Membaca dari `devices/{deviceId}`.
  Stream<MonitoringModel> deviceStream(String deviceId) {
    _guardInitialized();
    final id = deviceId.trim();

    return _deviceRefFor(id).onValue.map((DatabaseEvent event) {
      try {
        final data = _toMap(event.snapshot.value);
        if (data == null || data.isEmpty) {
          return MonitoringModel.noData(deviceId: id);
        }
        return MonitoringModel.fromMap(data);
      } catch (error) {
        debugPrint('[FirebaseService] deviceStream($id) parse error: $error');
        return MonitoringModel.noData(deviceId: id);
      }
    });
  }

  /// Stream daftar history secara realtime.
  ///
  /// Membaca dari `history/`. Dibatasi 100 data terbaru.
  Stream<List<HistoryModel>> historyStream() {
    _guardInitialized();

    return _historyRef()
        .orderByChild('timestamp')
        .limitToLast(100)
        .onValue
        .map((DatabaseEvent event) {
      try {
        final List<HistoryModel> items = [];
        final raw = _toMap(event.snapshot.value);

        if (raw != null && raw.isNotEmpty) {
          for (final entry in raw.entries) {
            final key = entry.key.toString();
            final value = _toMap(entry.value);
            if (value != null) {
              items.add(HistoryModel.fromMap(value, id: key));
            }
          }

          // Urutkan descending berdasarkan timestamp
          items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }

        return items;
      } catch (error) {
        debugPrint('[FirebaseService] historyStream parse error: $error');
        return [];
      }
    });
  }

  /// Stream data pairing — membaca dari `pairings/`.
  Stream<List<PairingModel>> pairingStream() {
    _guardInitialized();

    return _pairingsRef().onValue.map((DatabaseEvent event) {
      try {
        final List<PairingModel> items = [];
        final raw = _toMap(event.snapshot.value);

        if (raw != null && raw.isNotEmpty) {
          for (final entry in raw.entries) {
            final key = entry.key.toString();
            final value = _toMap(entry.value);
            if (value != null) {
              items.add(PairingModel.fromMap(value, id: key));
            }
          }
        }

        return items;
      } catch (error) {
        debugPrint('[FirebaseService] pairingStream parse error: $error');
        return [];
      }
    });
  }

  /// Stream daftar semua devices — membaca dari `devices/`.
  Stream<Map<String, MonitoringModel>> devicesListStream() {
    _guardInitialized();

    return _database!.ref(AppConstants.devicesPath).onValue.map(
      (DatabaseEvent event) {
        try {
          final Map<String, MonitoringModel> result = {};
          final raw = _toMap(event.snapshot.value);

          if (raw != null && raw.isNotEmpty) {
            for (final entry in raw.entries) {
              final key = entry.key.toString();
              final value = _toMap(entry.value);
              if (value != null) {
                result[key] = MonitoringModel.fromMap(value);
              }
            }
          }

          return result;
        } catch (error) {
          debugPrint(
            '[FirebaseService] devicesListStream parse error: $error',
          );
          return {};
        }
      },
    );
  }

  /// Stream status backend — membaca dari `backend/status`.
  ///
  /// Data: online, timestamp, firebaseConnected, etc.
  Stream<Map<String, dynamic>> backendStatusStream() {
    _guardInitialized();

    return _backendStatusRef().onValue.map((DatabaseEvent event) {
      try {
        final data = _toMap(event.snapshot.value);
        if (data == null || data.isEmpty) {
          return <String, dynamic>{};
        }
        return Map<String, dynamic>.from(data);
      } catch (error) {
        debugPrint(
          '[FirebaseService] backendStatusStream parse error: $error',
        );
        return <String, dynamic>{};
      }
    });
  }

  /// Cek status koneksi ke Firebase Realtime Database.
  Future<bool> isConnected() async {
    try {
      if (!_initialized || _database == null) return false;

      final completer = Completer<bool>();
      late final StreamSubscription<DatabaseEvent> subscription;

      subscription = _infoConnectedRef().onValue.listen(
        (DatabaseEvent event) {
          final connected = event.snapshot.value as bool? ?? false;
          if (!completer.isCompleted) {
            completer.complete(connected);
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          subscription.cancel();
          return false;
        },
      );

      await subscription.cancel();
      return result;
    } catch (error) {
      debugPrint('[FirebaseService] isConnected error: $error');
      return false;
    }
  }
}
