import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/monitoring_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../services/local_notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_stage.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/offline_detector.dart';
import '../utils/system_labels.dart';
import '../widgets/battery_card.dart';
import '../widgets/signal_card.dart';
import '../widgets/status_card.dart';

/// Dashboard — membaca data dari MonitoringProvider.
///
/// State yang ditampilkan:
/// - Loading   : indikator loading
/// - Error     : Card error
/// - No Data   : teks "Menunggu data ESP32"
/// - Data      : monitoring dari Firebase
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _initialized = false;
  LatLng? _workerPosition;
  StreamSubscription<Position>? _workerSubscription;
  _ConnectionDisplayState? _lastSenderConnection;
  _ConnectionDisplayState? _lastReceiverConnection;
  String? _lastReceiverDebugKey;

  /// True jika perangkat pernah ONLINE sejak aplikasi dibuka (sesi ini).
  bool _senderSeenThisSession = false;
  bool _receiverSeenThisSession = false;

  @override
  void initState() {
    super.initState();
    _startWorkerTracking();
  }

  @override
  void dispose() {
    _workerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startWorkerTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final current = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _workerPosition = LatLng(current.latitude, current.longitude);
      });
    } catch (_) {
      // Lanjut ke stream jika posisi awal gagal.
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _workerSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _workerPosition = LatLng(position.latitude, position.longitude);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final provider = context.read<MonitoringProvider>();
    if (provider.isInitialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mon = context.read<MonitoringProvider>();
      if (!mon.isInitialized) {
        mon.initialize();
      }
    });
  }

  void _syncConnectionState(
    MonitoringProvider monProv,
    AppStateProvider appState,
    SettingsProvider settings,
  ) {
    _updateSessionPresence(monProv);

    final sender = _resolveDeviceConnection(
      monProv,
      seenThisSession: _senderSeenThisSession,
      hasDeviceData: _hasSenderData(monProv.monitoring),
    );
    final receiver = _resolveDeviceConnection(
      monProv,
      seenThisSession: _receiverSeenThisSession,
      hasDeviceData: _hasReceiverData(monProv.monitoring),
    );
    final receiverLastUpdate =
        _formatConnectionLastUpdate(monProv.monitoring, receiver);

    final receiverDebugKey = '$receiver|$receiverLastUpdate';
    if (receiverDebugKey != _lastReceiverDebugKey) {
      _lastReceiverDebugKey = receiverDebugKey;
      debugPrint('Receiver Status: ${_connectionStateLabel(receiver)}');
      debugPrint('Receiver Last Update: $receiverLastUpdate');
    }

    // Sync Application Status setelah frame — hindari notify di tengah build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      appState.syncMonitoring(
        monitoring: monProv.monitoring,
        senderState: _connectionStateLabel(sender),
        receiverState: _connectionStateLabel(receiver),
      );
    });

    if (settings.notificationEnabled && AppStage.localNotificationEnabled) {
      _DashboardConnectionNotifier.notify(
        deviceName: 'Sender',
        previous: _lastSenderConnection,
        current: sender,
      );
      _DashboardConnectionNotifier.notify(
        deviceName: 'Receiver',
        previous: _lastReceiverConnection,
        current: receiver,
      );
    }

    _lastSenderConnection = sender;
    _lastReceiverConnection = receiver;
  }

  void _updateSessionPresence(MonitoringProvider mon) {
    if (!mon.isInitialized || mon.isLoading) return;
    final monitoring = mon.monitoring;
    if (monitoring == null || !monitoring.hasData) return;
    if (OfflineDetector.isOffline(monitoring)) return;

    if (_hasSenderData(monitoring)) {
      _senderSeenThisSession = true;
    }
    if (_hasReceiverData(monitoring)) {
      _receiverSeenThisSession = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<MonitoringProvider, AppStateProvider, SettingsProvider>(
      builder: (context, monProv, appState, settings, _) {
        _syncConnectionState(monProv, appState, settings);

        // State: Loading (saat pertama kali, belum ada data)
        if (monProv.isLoading && monProv.monitoring == null) {
          return _buildLoading(context);
        }

        // State: Error (saat gagal, belum pernah dapat data)
        if (monProv.errorMessage != null && monProv.monitoring == null) {
          return _buildError(context, monProv.errorMessage!);
        }

        final theme = Theme.of(context);
        final subtitle = monProv.displaySubtitle;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _StageBanner(stage: appState.stage),
            const SizedBox(height: 16),
            Text(
              'Monitoring',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
            const SizedBox(height: 16),
            StatusCard(status: monProv.currentStatus),
            const SizedBox(height: 16),
            _DeviceConnectionSection(
              monitoringProvider: monProv,
              senderSeenThisSession: _senderSeenThisSession,
              receiverSeenThisSession: _receiverSeenThisSession,
            ),
            const SizedBox(height: 16),
            _DashboardMapCard(
              monitoring: monProv.monitoring,
              workerPosition: _workerPosition,
            ),
            const SizedBox(height: 16),
            _GpsDistanceCard(
              monitoring: monProv.monitoring,
              workerPosition: _workerPosition,
            ),
            const SizedBox(height: 16),
            _SystemStatusCard(state: appState),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BatteryCard(percent: monProv.displayBattery),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SignalCard(signal: monProv.displaySignal),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DistancePlaceholder(distance: monProv.displayDistance),
          ],
        );
      },
    );
  }

  /// Tampilan loading.
  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Menghubungkan ke Firebase...',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan error.
  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: AppColors.danger),
                const SizedBox(height: 16),
                const Text(
                  'Gagal Terhubung',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    context.read<MonitoringProvider>().refresh();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Peta ringkas Dashboard — Sender, Receiver, Worker.
class _DashboardMapCard extends StatefulWidget {
  const _DashboardMapCard({
    this.monitoring,
    this.workerPosition,
  });

  final MonitoringModel? monitoring;
  final LatLng? workerPosition;

  @override
  State<_DashboardMapCard> createState() => _DashboardMapCardState();
}

class _DashboardMapCardState extends State<_DashboardMapCard> {
  static const LatLng _initialPosition = LatLng(-6.914744, 107.609810);
  /// Zoom fokus 16–17 saat hanya marker User (Kondisi 1 & 5).
  static const double _userZoom = 16.5;
  /// Threshold perubahan koordinat signifikan (meter) sebelum kamera di-update.
  static const double _significantMoveMeters = 25;

  final MapController _mapController = MapController();
  String? _lastPresenceKey;
  String? _lastOnlineReportKey;
  LatLng? _lastFitUser;
  LatLng? _lastFitSender;
  LatLng? _lastFitReceiver;
  String _cameraMode = 'CENTER USER';

  /// Sender online: data valid + heartbeat masih segar.
  bool _isSenderOnline(MonitoringModel? monitoring) =>
      _isSenderTelemetryOnline(monitoring);

  /// Receiver ikut pulse telemetry Sender.
  bool _isReceiverOnline(MonitoringModel? monitoring) =>
      _isReceiverTelemetryOnline(monitoring);

  String _formatLastUpdate(MonitoringModel? monitoring) {
    if (monitoring == null || monitoring.timestamp <= 0) return '--';
    return Formatters.dateTime(monitoring.timestamp);
  }

  void _logDeviceOnlineReport({
    required MonitoringModel? monitoring,
    required bool senderOnline,
    required bool receiverOnline,
  }) {
    final senderLat = monitoring?.latitude;
    final senderLng = monitoring?.longitude;
    final receiverLat = monitoring?.receiverLatitude;
    final receiverLng = monitoring?.receiverLongitude;
    final senderStatus = monitoring?.status ?? SensorStatus.unknown;
    final isStale = monitoring != null &&
        monitoring.hasData &&
        OfflineDetector.isOffline(monitoring);

    debugPrint('Sender Status: $senderStatus');
    debugPrint('Receiver Status: ${receiverOnline ? 'ONLINE' : 'OFFLINE'}');
    debugPrint('Sender Last Update: ${_formatLastUpdate(monitoring)}');
    debugPrint(
      'Receiver Last Update: ${receiverOnline ? _formatLastUpdate(monitoring) : '--'}',
    );
    debugPrint('Sender Latitude: ${senderLat ?? 'null'}');
    debugPrint('Sender Longitude: ${senderLng ?? 'null'}');
    debugPrint('Receiver Latitude: ${receiverLat ?? 'null'}');
    debugPrint('Receiver Longitude: ${receiverLng ?? 'null'}');

    debugPrint('DEVICE ONLINE REPORT');
    debugPrint('Sender');
    debugPrint('Online: ${senderOnline ? 'YES' : 'NO'}');
    if (senderOnline) {
      debugPrint('Reason: telemetry fresh + coordinates available');
    } else if (monitoring == null || !monitoring.hasData) {
      debugPrint('Reason: no monitoring data from Firebase');
    } else if (senderLat == null || senderLng == null) {
      debugPrint('Reason: coordinates not available');
    } else if (isStale) {
      debugPrint(
        'Reason: last update older than '
        '${AppConstants.senderOfflineThresholdSec}s (stale last known location)',
      );
    } else {
      debugPrint('Reason: device not active');
    }

    debugPrint('Receiver');
    debugPrint('Online: ${receiverOnline ? 'YES' : 'NO'}');
    if (receiverOnline) {
      debugPrint('Reason: sender online + receiver coordinates available');
    } else if (receiverLat == null || receiverLng == null) {
      debugPrint('Reason: receiver coordinates not available');
    } else if (!_isSenderOnline(monitoring)) {
      debugPrint(
        'Reason: sender offline — receiver coords kept as history only',
      );
    } else {
      debugPrint('Reason: receiver not active');
    }
  }

  ({LatLng? sender, LatLng? receiver}) _resolveActiveMarkers(
    MonitoringModel? monitoring,
  ) {
    final senderOnline = _isSenderOnline(monitoring);
    final receiverOnline = _isReceiverOnline(monitoring);

    final onlineReportKey = '$senderOnline|$receiverOnline';
    if (onlineReportKey != _lastOnlineReportKey) {
      _lastOnlineReportKey = onlineReportKey;
      _logDeviceOnlineReport(
        monitoring: monitoring,
        senderOnline: senderOnline,
        receiverOnline: receiverOnline,
      );
    }

    final LatLng? sender = senderOnline
        ? LatLng(monitoring!.latitude!, monitoring.longitude!)
        : null;
    final LatLng? receiver = receiverOnline
        ? LatLng(
            monitoring!.receiverLatitude!,
            monitoring.receiverLongitude!,
          )
        : null;

    return (sender: sender, receiver: receiver);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case SensorStatus.normal:
        return Colors.green;
      case SensorStatus.noise:
        return Colors.yellow.shade700;
      case SensorStatus.danger:
        return Colors.red;
      case SensorStatus.offline:
        return Colors.lightBlue;
      case SensorStatus.unknown:
      default:
        return Colors.purple;
    }
  }

  bool _movedSignificantly(LatLng? previous, LatLng? next) {
    if (previous == null && next == null) return false;
    if (previous == null || next == null) return true;
    return Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          next.latitude,
          next.longitude,
        ) >=
        _significantMoveMeters;
  }

  String _resolveCameraMode({
    required LatLng? user,
    required LatLng? sender,
    required LatLng? receiver,
  }) {
    final hasUser = user != null;
    final hasSender = sender != null;
    final hasReceiver = receiver != null;

    if (hasUser && hasSender && hasReceiver) return 'FIT ALL';
    if (hasUser && hasSender) return 'FIT USER+SENDER';
    if (hasUser) return 'CENTER USER';
    if (hasSender && hasReceiver) return 'FIT SENDER+RECEIVER';
    return 'CENTER USER';
  }

  void _logCameraReport({
    required LatLng? user,
    required LatLng? sender,
    required LatLng? receiver,
    required String mode,
  }) {
    debugPrint('CAMERA BEHAVIOR REPORT');
    debugPrint('User Marker: ${user != null ? 'AVAILABLE' : 'NULL'}');
    debugPrint('Sender Marker: ${sender != null ? 'AVAILABLE' : 'NULL'}');
    debugPrint('Receiver Marker: ${receiver != null ? 'AVAILABLE' : 'NULL'}');
    debugPrint('Current Camera Mode: $mode');
  }

  /// Update kamera hanya saat marker muncul/hilang atau koordinat berubah signifikan.
  void _maybeUpdateCamera({
    required LatLng? user,
    required LatLng? sender,
    required LatLng? receiver,
  }) {
    final fitPoints = <LatLng>[
      if (user != null) user,
      if (sender != null) sender,
      if (receiver != null) receiver,
    ];
    if (!mounted || fitPoints.isEmpty) return;

    final presenceKey =
        '${user != null}|${sender != null}|${receiver != null}';
    final presenceChanged = presenceKey != _lastPresenceKey;
    final coordsChanged = _movedSignificantly(_lastFitUser, user) ||
        _movedSignificantly(_lastFitSender, sender) ||
        _movedSignificantly(_lastFitReceiver, receiver);

    if (!presenceChanged && !coordsChanged && _lastPresenceKey != null) {
      return;
    }

    _lastPresenceKey = presenceKey;
    _lastFitUser = user;
    _lastFitSender = sender;
    _lastFitReceiver = receiver;
    _cameraMode = _resolveCameraMode(
      user: user,
      sender: sender,
      receiver: receiver,
    );
    _logCameraReport(
      user: user,
      sender: sender,
      receiver: receiver,
      mode: _cameraMode,
    );

    final padding = fitPoints.length >= 3
        ? const EdgeInsets.all(56)
        : const EdgeInsets.all(40);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (fitPoints.length == 1) {
        _mapController.move(fitPoints.first, _userZoom);
        return;
      }
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: fitPoints,
          padding: padding,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitoring = widget.monitoring;
    final status = monitoring?.status ?? SensorStatus.unknown;
    final user = widget.workerPosition;

    final active = _resolveActiveMarkers(monitoring);
    final sender = active.sender;
    final receiver = active.receiver;

    // Fokus awal: lokasi pengguna. Fallback ke Bandung jika GPS belum siap.
    final center = user ?? _initialPosition;

    final markers = <Marker>[];

    if (user != null) {
      markers.add(
        Marker(
          point: user,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: const Tooltip(
            message: 'User',
            child: Icon(
              Icons.person_pin_circle,
              color: Colors.orange,
              size: 40,
            ),
          ),
        ),
      );
    }

    if (sender != null) {
      markers.add(
        Marker(
          point: sender,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: Tooltip(
            message: 'TrackSafe Sender\nStatus: $status',
            child: Icon(
              Icons.train,
              color: _colorForStatus(status),
              size: 40,
            ),
          ),
        ),
      );
    }

    if (receiver != null) {
      markers.add(
        Marker(
          point: receiver,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: const Tooltip(
            message: 'Receiver',
            child: Icon(
              Icons.radio,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ),
      );
    }

    _maybeUpdateCamera(
      user: user,
      sender: sender,
      receiver: receiver,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Peta Monitoring',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _userZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tracksafe.tracksafe_app',
                  ),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu jarak GPS — Worker→Sender dan Sender→Receiver.
class _GpsDistanceCard extends StatelessWidget {
  const _GpsDistanceCard({
    required this.monitoring,
    required this.workerPosition,
  });

  final MonitoringModel? monitoring;
  final LatLng? workerPosition;

  static String _formatMeters(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _workerToSenderLabel() {
    if (!_isSenderTelemetryOnline(monitoring)) {
      if (!_hasSenderData(monitoring)) {
        return 'WAITING';
      }
      return 'Sender OFF';
    }

    final worker = workerPosition;
    final senderLat = monitoring!.latitude!;
    final senderLng = monitoring!.longitude!;
    if (worker == null) return '--';

    return _formatMeters(
      Geolocator.distanceBetween(
        worker.latitude,
        worker.longitude,
        senderLat,
        senderLng,
      ),
    );
  }

  String _senderToReceiverLabel() {
    if (!_isReceiverTelemetryOnline(monitoring)) {
      if (!_hasReceiverData(monitoring)) {
        return 'WAITING';
      }
      return 'Receiver OFF';
    }

    return _formatMeters(
      Geolocator.distanceBetween(
        monitoring!.latitude!,
        monitoring!.longitude!,
        monitoring!.receiverLatitude!,
        monitoring!.receiverLongitude!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senderOnline = _isSenderTelemetryOnline(monitoring);
    final receiverOnline = _isReceiverTelemetryOnline(monitoring);
    final workerSenderValid = senderOnline && workerPosition != null;
    final senderReceiverValid = receiverOnline;

    _logDistanceValidationReport(
      monitoring: monitoring,
      senderOnline: senderOnline,
      receiverOnline: receiverOnline,
      workerSenderValid: workerSenderValid,
      senderReceiverValid: senderReceiverValid,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Monitoring Distance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _distanceRow(
              context,
              icon: Icons.person_pin_circle,
              iconColor: Colors.orange,
              label: 'Worker → Sender',
              value: _workerToSenderLabel(),
            ),
            const SizedBox(height: 12),
            _distanceRow(
              context,
              icon: Icons.radio,
              iconColor: Colors.blue,
              label: 'Sender → Receiver',
              value: _senderToReceiverLabel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _distanceRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isOff = value.contains('OFF') || value == 'WAITING';

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: isOff ? AppColors.offline : null,
          ),
        ),
      ],
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        'TAHAP $stage / 11 · Flutter UI  ·  '
        '${AppStage.firebaseEnabled ? 'Firebase ON' : 'Firebase OFF'}  ·  '
        '${AppStage.backendEnabled ? 'Backend ON' : 'Backend OFF'}  ·  '
        '${AppStage.localNotificationEnabled ? 'Notif ON' : 'Notif OFF'}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard({required this.state});

  final AppStateProvider state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Application Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statusRow(
              context,
              icon: Icons.cloud_outlined,
              label: 'Backend',
              value: state.backendLabel,
            ),
            _statusRow(
              context,
              icon: Icons.storage_outlined,
              label: 'Firebase',
              value: state.firebaseLabel,
            ),
            _statusRow(
              context,
              icon: Icons.train,
              label: 'Sender',
              value: state.senderLabel,
            ),
            _statusRow(
              context,
              icon: Icons.sensors,
              label: 'Receiver',
              value: state.receiverLabel,
            ),
            _statusRow(
              context,
              icon: Icons.schedule,
              label: 'Last Update',
              value: state.lastUpdateLabel,
            ),
            _statusRow(
              context,
              icon: Icons.battery_std,
              label: 'Battery',
              value: state.batteryLabel,
            ),
            _statusRow(
              context,
              icon: Icons.signal_cellular_alt,
              label: 'Signal',
              value: state.signalLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final color = _indicatorColor(label, value);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _indicatorColor(String label, String value) {
    final v = value.toUpperCase().trim();

    if (v == 'ONLINE' ||
        v == SystemLabels.backendOnline.toUpperCase() ||
        v == SystemLabels.firebaseConnected.toUpperCase() ||
        value == SystemLabels.modeProduction) {
      return AppColors.online;
    }

    if (v == 'OFF' ||
        v == SystemLabels.backendOffline.toUpperCase() ||
        v == SystemLabels.firebaseNotConnected.toUpperCase()) {
      return AppColors.offline;
    }

    if (v == 'CONNECTING' ||
        v == 'CHECKING' ||
        v == SystemLabels.backendChecking.toUpperCase()) {
      return AppColors.warning;
    }

    if (v == 'WAITING' ||
        value == SystemLabels.placeholder ||
        value == SystemLabels.lastUpdateNone) {
      return AppColors.neutral;
    }

    if (label == 'Battery' || label == 'Signal') {
      if (value == SystemLabels.placeholder) return AppColors.neutral;
      return AppColors.online;
    }

    if (label == 'Last Update') {
      return value == SystemLabels.lastUpdateNone
          ? AppColors.neutral
          : AppColors.online;
    }

    if (label == 'Application Mode') return AppColors.primary;
    return AppColors.neutral;
  }
}

class _DistancePlaceholder extends StatelessWidget {
  const _DistancePlaceholder({this.distance});

  final int? distance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText =
        distance == null ? SystemLabels.placeholder : '$distance cm';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.straighten, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jarak Sensor',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayText,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConnectionDisplayState {
  online,
  offline,
  connecting,
  waiting,
}

String? _lastDistanceValidationKey;

bool _hasSenderData(MonitoringModel? monitoring) {
  return monitoring != null &&
      monitoring.hasData &&
      monitoring.latitude != null &&
      monitoring.longitude != null;
}

bool _hasReceiverData(MonitoringModel? monitoring) {
  return monitoring != null &&
      monitoring.hasData &&
      monitoring.receiverLatitude != null &&
      monitoring.receiverLongitude != null;
}

/// Perangkat online: koordinat tersedia + telemetry masih segar.
bool _isSenderTelemetryOnline(MonitoringModel? monitoring) {
  if (!_hasSenderData(monitoring)) return false;
  return !OfflineDetector.isOffline(monitoring!);
}

/// Receiver ikut pulse telemetry Sender (tidak ada heartbeat terpisah).
bool _isReceiverTelemetryOnline(MonitoringModel? monitoring) {
  if (!_isSenderTelemetryOnline(monitoring)) return false;
  return _hasReceiverData(monitoring);
}

void _logDistanceValidationReport({
  required MonitoringModel? monitoring,
  required bool senderOnline,
  required bool receiverOnline,
  required bool workerSenderValid,
  required bool senderReceiverValid,
}) {
  final key =
      '$senderOnline|$receiverOnline|$workerSenderValid|$senderReceiverValid';
  if (key == _lastDistanceValidationKey) return;
  _lastDistanceValidationKey = key;

  final senderStatus = senderOnline
      ? 'ONLINE'
      : (_hasSenderData(monitoring) ? 'OFF' : 'WAITING');
  final receiverStatus = receiverOnline
      ? 'ONLINE'
      : (_hasReceiverData(monitoring) ? 'OFF' : 'WAITING');

  debugPrint('DISTANCE VALIDATION REPORT');
  debugPrint('Sender Status: $senderStatus');
  debugPrint('Receiver Status: $receiverStatus');
  debugPrint(
    'Worker → Sender: ${workerSenderValid ? 'VALID' : 'SKIPPED'}',
  );
  debugPrint(
    'Sender → Receiver: ${senderReceiverValid ? 'VALID' : 'SKIPPED'}',
  );

  if (workerSenderValid || senderReceiverValid) {
    debugPrint('Root Cause: devices online — distance calculated from fresh coordinates');
  } else if (monitoring != null &&
      monitoring.hasData &&
      OfflineDetector.isOffline(monitoring)) {
    debugPrint(
      'Root Cause: stale last known coordinates — '
      'timestamp older than ${AppConstants.senderOfflineThresholdSec}s',
    );
  } else if (!_hasSenderData(monitoring)) {
    debugPrint('Root Cause: sender coordinates not available');
  } else if (!_hasReceiverData(monitoring)) {
    debugPrint('Root Cause: receiver coordinates not available');
  } else {
    debugPrint('Root Cause: device offline or waiting for telemetry');
  }
}

/// Logika status seragam untuk Sender dan Receiver.
///
/// CONNECTING — sedang mencoba koneksi
/// WAITING    — belum pernah online sejak aplikasi dibuka
/// ONLINE     — sedang mengirim data (telemetry segar)
/// OFF        — pernah online di sesi ini, lalu berhenti update
_ConnectionDisplayState _resolveDeviceConnection(
  MonitoringProvider mon, {
  required bool seenThisSession,
  required bool hasDeviceData,
}) {
  if (!mon.isInitialized || mon.isLoading) {
    return _ConnectionDisplayState.connecting;
  }

  final monitoring = mon.monitoring;
  final telemetryFresh = monitoring != null &&
      monitoring.hasData &&
      !OfflineDetector.isOffline(monitoring);

  if (telemetryFresh && hasDeviceData) {
    return _ConnectionDisplayState.online;
  }

  if (seenThisSession) {
    return _ConnectionDisplayState.offline;
  }

  return _ConnectionDisplayState.waiting;
}

String _connectionStateLabel(_ConnectionDisplayState state) {
  switch (state) {
    case _ConnectionDisplayState.online:
      return 'ONLINE';
    case _ConnectionDisplayState.offline:
      return 'OFF';
    case _ConnectionDisplayState.connecting:
      return 'CONNECTING';
    case _ConnectionDisplayState.waiting:
      return 'WAITING';
  }
}

String _formatConnectionLastUpdate(
  MonitoringModel? monitoring,
  _ConnectionDisplayState state,
) {
  if (state == _ConnectionDisplayState.waiting ||
      state == _ConnectionDisplayState.connecting) {
    return '--';
  }
  if (monitoring == null || monitoring.timestamp <= 0) return '--';
  return Formatters.time(monitoring.timestamp);
}

class _DeviceConnectionSection extends StatelessWidget {
  const _DeviceConnectionSection({
    required this.monitoringProvider,
    required this.senderSeenThisSession,
    required this.receiverSeenThisSession,
  });

  final MonitoringProvider monitoringProvider;
  final bool senderSeenThisSession;
  final bool receiverSeenThisSession;

  @override
  Widget build(BuildContext context) {
    final monitoring = monitoringProvider.monitoring;
    final senderState = _resolveDeviceConnection(
      monitoringProvider,
      seenThisSession: senderSeenThisSession,
      hasDeviceData: _hasSenderData(monitoring),
    );
    final receiverState = _resolveDeviceConnection(
      monitoringProvider,
      seenThisSession: receiverSeenThisSession,
      hasDeviceData: _hasReceiverData(monitoring),
    );

    return Column(
      children: [
        _DeviceConnectionPanel(
          deviceIcon: Icons.train,
          deviceName: 'Sender',
          state: senderState,
          lastUpdate: _formatConnectionLastUpdate(monitoring, senderState),
        ),
        const SizedBox(height: 12),
        _DeviceConnectionPanel(
          deviceIcon: Icons.sensors,
          deviceName: 'Receiver',
          state: receiverState,
          lastUpdate: _formatConnectionLastUpdate(monitoring, receiverState),
        ),
      ],
    );
  }
}

class _DeviceConnectionPanel extends StatelessWidget {
  const _DeviceConnectionPanel({
    required this.deviceIcon,
    required this.deviceName,
    required this.state,
    required this.lastUpdate,
  });

  final IconData deviceIcon;
  final String deviceName;
  final _ConnectionDisplayState state;
  final String lastUpdate;

  ({IconData statusIcon, Color color, String label}) get _visual {
    switch (state) {
      case _ConnectionDisplayState.online:
        return (
          statusIcon: Icons.check_circle,
          color: AppColors.online,
          label: 'ONLINE',
        );
      case _ConnectionDisplayState.offline:
        return (
          statusIcon: Icons.cancel,
          color: AppColors.offline,
          label: 'OFF',
        );
      case _ConnectionDisplayState.connecting:
        return (
          statusIcon: Icons.sync,
          color: AppColors.warning,
          label: 'CONNECTING',
        );
      case _ConnectionDisplayState.waiting:
        return (
          statusIcon: Icons.schedule,
          color: AppColors.neutral,
          label: 'WAITING',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _visual;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: visual.color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(deviceIcon, size: 28, color: visual.color),
                const SizedBox(width: 10),
                Text(
                  deviceName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(visual.statusIcon, size: 18, color: visual.color),
                const SizedBox(width: 8),
                Text(
                  visual.label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: visual.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Last Update',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lastUpdate,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardConnectionNotifier {
  _DashboardConnectionNotifier._();

  static int _nextNotificationId = 100;

  static Future<void> notify({
    required String deviceName,
    required _ConnectionDisplayState? previous,
    required _ConnectionDisplayState current,
  }) async {
    if (!AppStage.localNotificationEnabled) return;
    if (!LocalNotificationService.instance.isInitialized) return;
    if (previous == null || previous == current) return;

    String? title;
    String? body;

    if (current == _ConnectionDisplayState.online) {
      if (previous == _ConnectionDisplayState.offline) {
        title = '$deviceName Reconnected';
        body = '$deviceName kembali online.';
      } else {
        title = '$deviceName Connected';
        body = '$deviceName berhasil terhubung.';
      }
    } else if (current == _ConnectionDisplayState.offline &&
        previous == _ConnectionDisplayState.online) {
      title = '$deviceName Disconnected';
      body = '$deviceName tidak mengirim data.';
    }

    if (title == null || body == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      _nextNotificationId++,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          LocalNotificationService.channelOffline,
          'Koneksi Perangkat',
          channelDescription: 'Notifikasi koneksi Sender dan Receiver',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );

    debugPrint('Notification Trigger: FOUND — $title');
  }
}
