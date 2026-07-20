/// Label status sistem untuk UI (bukan rule-based sensor).
class SystemLabels {
  SystemLabels._();

  static const String modeDevelopment = 'Development';
  static const String modeProduction = 'Production';

  static const String backendNotConfigured = 'Not Configured';
  static const String backendNotStarted = 'Not Started';
  static const String backendChecking = 'CHECKING';
  /// Status dari GET /api/status (Sprint 32).
  static const String backendOnline = 'ONLINE';
  static const String backendOffline = 'OFFLINE';
  static const String backendError = 'ERROR';

  static const String firebaseNotConnected = 'Not Connected';
  static const String firebaseChecking = 'Checking';
  static const String firebaseConnected = 'Connected';

  static const String senderUnknown = 'Unknown';
  static const String senderWaiting = 'WAITING';
  static const String senderConnecting = 'CONNECTING';
  static const String senderOnline = 'ONLINE';
  static const String senderOff = 'OFF';

  static const String receiverWaiting = 'WAITING';
  static const String receiverConnecting = 'CONNECTING';
  static const String receiverOnline = 'ONLINE';
  static const String receiverOff = 'OFF';

  static const String monitoringWaiting = 'Menunggu data ESP32.';
  static const String lastUpdateNone = 'Belum ada data';
  static const String placeholder = '--';
}
