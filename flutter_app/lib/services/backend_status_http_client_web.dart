// ignore_for_file: depend_on_referenced_packages
// http is available transitively; not added as a direct dependency per sprint rules.

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import 'backend_status_http_response.dart';

/// Flutter Web — [BrowserClient] (package:http), no dart:io.
class BackendStatusHttpClient {
  BackendStatusHttpClient({http.Client? client})
      : _client = client ?? BrowserClient();

  final http.Client _client;

  Future<BackendStatusHttpResponse> getJson(Uri uri) async {
    final response = await _client
        .get(
          uri,
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));

    return BackendStatusHttpResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  void close() {
    _client.close();
  }
}
