// Platform HTTP client for BackendStatusService.
//
// - VM (Android / iOS / Desktop): dart:io HttpClient
// - Web: package:http BrowserClient
//
// Conditional import ensures dart:io is never loaded on Flutter Web.
export 'backend_status_http_client_io.dart'
    if (dart.library.html) 'backend_status_http_client_web.dart';
