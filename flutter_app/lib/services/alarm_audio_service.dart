import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// AlarmAudioService — pemutar audio alarm keselamatan.
///
/// Method:
/// - [initialize]     : siapkan AudioPlayer
/// - [playWarning]    : bunyi warning sekali (NOISE)
/// - [playCritical]   : bunyi critical loop (DANGER)
/// - [playOffline]    : bunyi offline sekali (OFFLINE)
/// - [stop]           : hentikan audio (NORMAL)
///
/// Hanya dipanggil dari [NotificationOrchestrator].
///
/// Web: AudioContext tidak boleh start sebelum gesture user (browser policy).
class AlarmAudioService {
  AlarmAudioService._();

  static final AlarmAudioService instance = AlarmAudioService._();

  AudioPlayer? _player;
  bool _initialized = false;
  bool _webGestureUnlocked = !kIsWeb;
  bool _webUnlockListenerInstalled = false;
  AlarmAudioKind? _playing;

  bool get isInitialized => _initialized;
  AlarmAudioKind? get playing => _playing;

  static const String _warningAsset = 'assets/sounds/warning.wav';
  static const String _criticalAsset = 'assets/sounds/critical.wav';
  static const String _offlineAsset = 'assets/sounds/offline.wav';

  Future<void> initialize() async {
    if (_initialized) return;

    // Web: jangan buat AudioPlayer / AudioContext sebelum ada gesture user.
    if (kIsWeb && !_webGestureUnlocked) {
      _installWebUnlockListener();
      debugPrint(
        '[AlarmAudioService] Web: defer init until user gesture',
      );
      return;
    }

    await _doInitialize();
  }

  Future<void> _doInitialize() async {
    if (_initialized) return;
    _player ??= AudioPlayer();
    await _player!.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
    debugPrint('[AlarmAudioService] Initialized');
  }

  void _installWebUnlockListener() {
    if (_webUnlockListenerInstalled) return;
    _webUnlockListenerInstalled = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onWebPointer);
  }

  void _onWebPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onWebPointer);
    // ignore: discarded_futures
    _unlockWebAudio();
  }

  Future<void> _unlockWebAudio() async {
    if (_webGestureUnlocked) return;
    _webGestureUnlocked = true;
    await _doInitialize();
    debugPrint('[AlarmAudioService] Web: audio unlocked after user gesture');
  }

  bool get _canAttemptPlay {
    if (!kIsWeb) return true;
    return _webGestureUnlocked;
  }

  /// NOISE — putar warning sekali. Tidak restart jika sudah warning.
  Future<void> playWarning() async {
    await _playOnce(AlarmAudioKind.warning, _warningAsset);
  }

  /// DANGER — putar critical secara loop. Tidak restart jika sudah critical.
  Future<void> playCritical() async {
    if (!_canAttemptPlay) {
      debugPrint(
        '[AlarmAudioService] skip playCritical — menunggu gesture user (web)',
      );
      return;
    }
    if (!_initialized) await _doInitialize();
    if (_playing == AlarmAudioKind.critical) return;

    final player = _player;
    if (player == null) return;

    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource(_stripAssetsPrefix(_criticalAsset)));
    _playing = AlarmAudioKind.critical;
    debugPrint('[AlarmAudioService] playCritical (loop)');
  }

  /// OFFLINE — putar offline sekali. Tidak restart jika sudah offline.
  Future<void> playOffline() async {
    await _playOnce(AlarmAudioKind.offline, _offlineAsset);
  }

  /// NORMAL — hentikan semua audio alarm.
  Future<void> stop() async {
    if (!_initialized) return;
    if (_playing == null) return;

    final player = _player;
    if (player == null) return;

    await player.stop();
    await player.setReleaseMode(ReleaseMode.stop);
    _playing = null;
    debugPrint('[AlarmAudioService] stop');
  }

  Future<void> _playOnce(AlarmAudioKind kind, String assetPath) async {
    if (!_canAttemptPlay) {
      debugPrint(
        '[AlarmAudioService] skip playOnce($kind) — menunggu gesture user (web)',
      );
      return;
    }
    if (!_initialized) await _doInitialize();
    // Level sama → jangan stop()+play() ulang.
    if (_playing == kind) return;

    final player = _player;
    if (player == null) return;

    await player.stop();
    await player.setReleaseMode(ReleaseMode.release);
    await player.play(AssetSource(_stripAssetsPrefix(assetPath)));
    _playing = kind;
    debugPrint('[AlarmAudioService] playOnce: $kind');
  }

  /// [AssetSource] mengharapkan path relatif tanpa prefix `assets/`.
  static String _stripAssetsPrefix(String path) {
    const prefix = 'assets/';
    if (path.startsWith(prefix)) {
      return path.substring(prefix.length);
    }
    return path;
  }
}

/// Jenis audio alarm yang sedang / terakhir diputar.
enum AlarmAudioKind {
  warning,
  critical,
  offline,
}
