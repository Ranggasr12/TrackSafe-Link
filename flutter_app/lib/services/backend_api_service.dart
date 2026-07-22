import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

/// REST client for TrackSafe backend device management.
///
/// Sesuai arsitektur final, Flutter hanya menggunakan backend untuk:
/// - POST /api/device/pair
/// - POST /api/device/unpair
/// - GET /api/device/list
/// - GET /api/device/pairing
///
/// Selain itu gunakan Firebase Realtime Database.
class BackendApiService {
  BackendApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => AppConstants.backendBaseUrl.replaceAll(RegExp(r'/$'), '');

  Future<Map<String, dynamic>?> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_base$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return map;
      }
      debugPrint('[BackendApi] POST $path failed: ${response.statusCode} $map');
      return null;
    } catch (e) {
      debugPrint('[BackendApi] POST $path error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$_base$path'))
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return map;
      }
      debugPrint('[BackendApi] GET $path failed: ${response.statusCode} $map');
      return null;
    } catch (e) {
      debugPrint('[BackendApi] GET $path error: $e');
      return null;
    }
  }

  /// POST /api/device/pair
  Future<bool> pairDevices({
    required String senderId,
    required String receiverId,
  }) async {
    final result = await _post('/api/device/pair', {
      'senderId': senderId,
      'receiverId': receiverId,
    });
    return result?['success'] == true;
  }

  /// POST /api/device/unpair
  Future<bool> unpairDevices({
    String? senderId,
    String? receiverId,
  }) async {
    final body = <String, dynamic>{};
    if (senderId != null && senderId.trim().isNotEmpty) {
      body['senderId'] = senderId.trim();
    }
    if (receiverId != null && receiverId.trim().isNotEmpty) {
      body['receiverId'] = receiverId.trim();
    }
    final result = await _post('/api/device/unpair', body);
    return result?['success'] == true;
  }

  /// GET /api/device/pairing/{deviceId}
  Future<Map<String, dynamic>?> getPairing(String deviceId) async {
    final id = deviceId.trim();
    if (id.isEmpty) return null;
    return _get('/api/device/pairing/$id');
  }

  /// GET /api/device/list
  Future<Map<String, dynamic>?> getDeviceList() async {
    return _get('/api/device/list');
  }

  void dispose() {
    _client.close();
  }
}
