import 'dart:convert';
import 'dart:io';

import 'backend_status_http_response.dart';

/// Android / iOS / Desktop — [HttpClient] (dart:io).
class BackendStatusHttpClient {
  BackendStatusHttpClient({HttpClient? client})
      : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<BackendStatusHttpResponse> getJson(Uri uri) async {
    final request = await _client.getUrl(uri).timeout(
      const Duration(seconds: 8),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(
      const Duration(seconds: 8),
    );
    final body = await response.transform(utf8.decoder).join();

    return BackendStatusHttpResponse(
      statusCode: response.statusCode,
      body: body,
    );
  }

  void close() {
    _client.close(force: true);
  }
}
