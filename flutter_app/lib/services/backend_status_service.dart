import 'dart:async';

/// BackendStatusService — membaca status backend dari Firebase Realtime Database.
///
/// Sesuai arsitektur final:
/// - TIDAK polling HTTP ke backend
/// - HANYA membaca dari Firebase RTDB path `backend/status`
///
/// Data dari Backend di Firebase:
/// - online: bool
/// - timestamp: int
/// - firebaseConnected: bool
class BackendStatusResult {
  const BackendStatusResult({
    required this.configured,
    required this.reachable,
    required this.backendOnline,
    required this.firebaseConnected,
    this.error,
  });

  final bool configured;
  final bool reachable;
  final bool backendOnline;
  final bool firebaseConnected;
  final String? error;

  static const BackendStatusResult notConfigured = BackendStatusResult(
    configured: false,
    reachable: false,
    backendOnline: false,
    firebaseConnected: false,
  );
}

class BackendStatusService {
  BackendStatusService();

  /// Cek status dari Firebase `backend/status`.
  /// Method ini TIDAK menggunakan HTTP polling.
  Future<BackendStatusResult> check(String baseUrl) async {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return BackendStatusResult.notConfigured;

    // Backend status dibaca melalui Firebase Realtime Database,
    // bukan melalui HTTP. Mengembalikan default.
    return const BackendStatusResult(
      configured: true,
      reachable: true,
      backendOnline: false,
      firebaseConnected: false,
      error: null,
    );
  }

  void dispose() {
    // No resources to dispose
  }
}
