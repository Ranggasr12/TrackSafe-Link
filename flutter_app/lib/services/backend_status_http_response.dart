/// Raw HTTP response from GET /api/status (platform-agnostic).
class BackendStatusHttpResponse {
  const BackendStatusHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}
