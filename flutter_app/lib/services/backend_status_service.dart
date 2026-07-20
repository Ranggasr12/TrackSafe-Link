import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
  BackendStatusService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<BackendStatusResult> check(String baseUrl) async {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return BackendStatusResult.notConfigured;

    final root = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final uri = Uri.parse('$root/api/status');

    try {
      final request = await _client.getUrl(uri).timeout(
            const Duration(seconds: 8),
          );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(
            const Duration(seconds: 8),
          );
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BackendStatusResult(
          configured: true,
          reachable: false,
          backendOnline: false,
          firebaseConnected: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const BackendStatusResult(
          configured: true,
          reachable: true,
          backendOnline: false,
          firebaseConnected: false,
          error: 'Invalid JSON shape',
        );
      }

      final map = Map<String, dynamic>.from(decoded);
      final backendRaw = map['backend']?.toString().toLowerCase().trim();
      final firebaseRaw = map['firebase']?.toString().toLowerCase().trim();
      final success = map['success'] == true;

      // Backend online jika field backend == online, atau success + HTTP 2xx.
      final backendOnline =
          backendRaw == 'online' || (success && backendRaw != 'offline');
      final firebaseConnected = firebaseRaw == 'connected';

      return BackendStatusResult(
        configured: true,
        reachable: true,
        backendOnline: backendOnline,
        firebaseConnected: firebaseConnected,
        error: success ? null : map['error']?.toString(),
      );
    } on TimeoutException {
      debugPrint('[BackendStatus] timeout GET /api/status');
      return const BackendStatusResult(
        configured: true,
        reachable: false,
        backendOnline: false,
        firebaseConnected: false,
        error: 'Timeout',
      );
    } catch (e) {
      debugPrint('[BackendStatus] error GET /api/status: $e');
      return BackendStatusResult(
        configured: true,
        reachable: false,
        backendOnline: false,
        firebaseConnected: false,
        error: e.toString(),
      );
    }
  }

  void dispose() {
    _client.close(force: true);
  }
}
