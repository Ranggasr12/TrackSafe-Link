import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/device_pairing_provider.dart';
import '../providers/monitoring_provider.dart';
import '../utils/constants.dart';
import '../utils/device_link_status.dart';
import '../utils/formatters.dart';
import '../models/monitoring_model.dart';

/// Peta monitoring — Sprint 28: Smart Safety Engine.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _SafetyLevel {
  aman,
  waspada,
  peringatan,
  bahaya,
  bahayaTinggi,
  evakuasi,
  unknown,
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const LatLng _initialPosition = LatLng(-6.914744, 107.609810);
  /// Zoom 16–17 saat hanya marker User (Kondisi 1 & 5).
  static const double _userZoom = 16.5;
  /// Threshold perubahan koordinat signifikan (meter) sebelum kamera di-update.
  static const double _significantMoveMeters = 25;

  static final DateFormat _dateId = DateFormat('d MMMM yyyy', 'id_ID');
  static final DateFormat _timeId = DateFormat('HH:mm:ss', 'id_ID');

  final MapController _mapController = MapController();
  final List<LatLng> _listTrack = <LatLng>[];

  /// Jalur rel (dummy) — lintasan contoh di sekitar Bandung.
  final List<LatLng> _railwayTrack = <LatLng>[
    const LatLng(-6.917500, 107.605000),
    const LatLng(-6.916200, 107.607000),
    const LatLng(-6.914744, 107.609810),
    const LatLng(-6.913200, 107.612000),
    const LatLng(-6.911800, 107.614200),
    const LatLng(-6.910500, 107.616500),
  ];

  bool _initialized = false;
  LatLng? _workerPosition;
  StreamSubscription<Position>? _workerSubscription;
  late final AnimationController _blinkController;

  String? _lastPresenceKey;
  LatLng? _lastFitUser;
  LatLng? _lastFitSender;
  LatLng? _lastFitReceiver;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _startWorkerTracking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final provider = context.read<MonitoringProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    }
  }

  @override
  void dispose() {
    _workerSubscription?.cancel();
    _blinkController.dispose();
    _mapController.dispose();
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

  void _appendTrackIfMoved(LatLng position) {
    final isNewPoint = _listTrack.isEmpty || _listTrack.last != position;
    if (!isNewPoint) return;
    // Jangan setState di dalam build — track ikut rebuild berikutnya.
    _listTrack.add(position);
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

    // Sprint 30: User saja → Center; User+Sender → Fit; User+Sender+Receiver → Fit
    if (hasUser && hasSender && hasReceiver) return 'FIT ALL';
    if (hasUser && hasSender) return 'FIT USER+SENDER';
    if (hasUser) return 'CENTER USER';
    if (hasSender && hasReceiver) return 'FIT SENDER+RECEIVER';
    return 'CENTER USER';
  }

  bool _isSenderOnline(MonitoringModel? monitoring) {
    if (monitoring == null || !monitoring.hasData) return false;
    final gps = DeviceLinkStatusResolver.gpsFixFromCoords(
      monitoring.latitude,
      monitoring.longitude,
    );
    return DeviceLinkStatusResolver.resolve(
          isLoading: false,
          seenThisSession: true,
          telemetry: monitoring,
          hasGpsFix: gps,
        ) ==
        DeviceLinkStatus.online;
  }

  bool _isReceiverOnline({
    required MonitoringModel? nested,
    required MonitoringModel? receiverNode,
  }) {
    final gpsFromNode = DeviceLinkStatusResolver.gpsFixFromCoords(
      receiverNode?.latitude,
      receiverNode?.longitude,
    );
    final gpsFromNested = nested != null &&
        nested.receiverLatitude != null &&
        nested.receiverLongitude != null;
    final telemetry =
        (receiverNode != null && receiverNode.hasData) ? receiverNode : null;

    return DeviceLinkStatusResolver.resolve(
          isLoading: false,
          seenThisSession: true,
          telemetry: telemetry,
          hasGpsFix: gpsFromNode || gpsFromNested,
        ) ==
        DeviceLinkStatus.online;
  }

  LatLng? _receiverLatLng({
    required MonitoringModel? nested,
    required MonitoringModel? receiverNode,
  }) {
    if (receiverNode?.latitude != null && receiverNode?.longitude != null) {
      return LatLng(receiverNode!.latitude!, receiverNode.longitude!);
    }
    if (nested?.receiverLatitude != null &&
        nested?.receiverLongitude != null) {
      return LatLng(nested!.receiverLatitude!, nested.receiverLongitude!);
    }
    return null;
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

    final mode = _resolveCameraMode(
      user: user,
      sender: sender,
      receiver: receiver,
    );
    _logCameraReport(
      user: user,
      sender: sender,
      receiver: receiver,
      mode: mode,
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

  String _formatCoord(double value) => value.toStringAsFixed(6);

  String _formatSpeed(double? speed) {
    if (speed == null) return '--';
    return '${speed.toStringAsFixed(1)} km/jam';
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return Formatters.noDataLabel;
    }
    final dt = Formatters.fromTimestamp(timestamp);
    return '${_dateId.format(dt)}\n${_timeId.format(dt)} WIB';
  }

  double? _distanceMeters(LatLng? worker, LatLng sender) {
    if (worker == null) return null;
    return Geolocator.distanceBetween(
      worker.latitude,
      worker.longitude,
      sender.latitude,
      sender.longitude,
    );
  }

  String _formatDistance(LatLng? worker, LatLng sender) {
    final meters = _distanceMeters(worker, sender);
    if (meters == null) return '--';
    if (meters < 1000) {
      return '${meters.round()} meter';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// Smart Safety Engine — status ESP32 + jarak Worker→Sender.
  _SafetyLevel _resolveSafety(String status, double? distanceMeters) {
    if (status == SensorStatus.normal) {
      return _SafetyLevel.aman;
    }

    if (status == SensorStatus.noise) {
      if (distanceMeters != null && distanceMeters <= 50) {
        return _SafetyLevel.peringatan;
      }
      // NOISE + jarak >100 m (dan rentang di antaranya) → Waspada
      return _SafetyLevel.waspada;
    }

    if (status == SensorStatus.danger) {
      if (distanceMeters != null && distanceMeters <= 20) {
        return _SafetyLevel.evakuasi;
      }
      if (distanceMeters != null && distanceMeters <= 50) {
        return _SafetyLevel.bahayaTinggi;
      }
      // DANGER + jarak >100 m (dan rentang di antaranya) → Bahaya
      return _SafetyLevel.bahaya;
    }

    return _SafetyLevel.unknown;
  }

  String _safetyLabel(_SafetyLevel level) {
    switch (level) {
      case _SafetyLevel.aman:
        return 'AMAN';
      case _SafetyLevel.waspada:
        return 'WASPADA';
      case _SafetyLevel.peringatan:
        return 'PERINGATAN';
      case _SafetyLevel.bahaya:
        return 'BAHAYA';
      case _SafetyLevel.bahayaTinggi:
        return 'BAHAYA TINGGI';
      case _SafetyLevel.evakuasi:
        return 'EVAKUASI SEKARANG';
      case _SafetyLevel.unknown:
        return '--';
    }
  }

  Color _safetyColor(_SafetyLevel level) {
    switch (level) {
      case _SafetyLevel.aman:
        return Colors.green;
      case _SafetyLevel.waspada:
        return Colors.yellow.shade700;
      case _SafetyLevel.peringatan:
        return Colors.orange;
      case _SafetyLevel.bahaya:
        return Colors.red;
      case _SafetyLevel.bahayaTinggi:
      case _SafetyLevel.evakuasi:
        return const Color(0xFFB71C1C);
      case _SafetyLevel.unknown:
        return Colors.grey;
    }
  }

  Future<void> _openNavigation(double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat belum tersedia.')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka Google Maps.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka Google Maps.')),
      );
    }
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyInfoRow(_SafetyLevel level) {
    final label = _safetyLabel(level);
    final color = _safetyColor(level);

    if (level == _SafetyLevel.evakuasi) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                'Status Keselamatan',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _blinkController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.35 + (_blinkController.value * 0.65),
                    child: child,
                  );
                },
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _infoRow('Status Keselamatan', label, valueColor: color);
  }

  Widget _buildInfoPanel({
    required String status,
    required double latitude,
    required double longitude,
    required double? speed,
    required int? timestamp,
    required String zonaAmanLabel,
    required String jarakLabel,
    required _SafetyLevel safetyLevel,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Status', status),
            _infoRow('Latitude', _formatCoord(latitude)),
            _infoRow('Longitude', _formatCoord(longitude)),
            _infoRow('Kecepatan', _formatSpeed(speed)),
            _infoRow('Timestamp', _formatTimestamp(timestamp)),
            _infoRow('Zona Aman', zonaAmanLabel),
            _infoRow('Jarak ke Sender', jarakLabel),
            _safetyInfoRow(safetyLevel),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openNavigation(latitude, longitude),
              icon: const Icon(Icons.navigation),
              label: const Text('Navigasi ke Lokasi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Monitoring'),
      ),
      body: Consumer2<MonitoringProvider, DevicePairingProvider>(
        builder: (context, provider, pairing, _) {
          final monitoring = provider.monitoring;
          final receiverNode = pairing.receiverTelemetry;
          final senderOnline = _isSenderOnline(monitoring);
          final receiverOnline = _isReceiverOnline(
            nested: monitoring,
            receiverNode: receiverNode,
          );

          // Marker hanya jika ONLINE — jangan tampilkan koordinat stale saat OFF.
          final LatLng? sender = senderOnline &&
                  monitoring?.latitude != null &&
                  monitoring?.longitude != null
              ? LatLng(monitoring!.latitude!, monitoring.longitude!)
              : null;
          final LatLng? receiver = receiverOnline
              ? _receiverLatLng(
                  nested: monitoring,
                  receiverNode: receiverNode,
                )
              : null;
          final user = _workerPosition;

          final status = provider.currentStatus;
          final isDanger = status == SensorStatus.danger;
          final zonaAmanLabel = isDanger ? 'BAHAYA' : 'AMAN';
          final markerColor = _colorForStatus(status);
          final distanceMeters =
              sender != null ? _distanceMeters(user, sender) : null;
          final jarakLabel =
              sender != null ? _formatDistance(user, sender) : '--';
          final safetyLevel = _resolveSafety(status, distanceMeters);

          if (sender != null) {
            _appendTrackIfMoved(sender);
          }

          _maybeUpdateCamera(
            user: user,
            sender: sender,
            receiver: receiver,
          );

          final polylines = <Polyline>[
            Polyline(
              points: _listTrack,
              strokeWidth: 5,
              color: Colors.blue,
            ),
            Polyline(
              points: _railwayTrack,
              strokeWidth: 6,
              color: Colors.grey.shade800,
              pattern: const StrokePattern.dotted(
                spacingFactor: 2.5,
              ),
            ),
          ];

          if (user != null && sender != null) {
            polylines.add(
              Polyline(
                points: [user, sender],
                strokeWidth: 3,
                color: Colors.orange,
              ),
            );
          }

          final markers = <Marker>[];

          if (user != null) {
            markers.add(
              Marker(
                point: user,
                width: 48,
                height: 48,
                alignment: Alignment.topCenter,
                child: const Tooltip(
                  message: 'User',
                  child: Icon(
                    Icons.person_pin_circle,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
              ),
            );
          }

          if (sender != null) {
            markers.add(
              Marker(
                point: sender,
                width: 48,
                height: 48,
                alignment: Alignment.topCenter,
                child: Tooltip(
                  message: 'TrackSafe Sender\nStatus: $status',
                  child: Icon(
                    Icons.location_on,
                    color: markerColor,
                    size: 48,
                  ),
                ),
              ),
            );
          }

          if (receiver != null) {
            markers.add(
              Marker(
                point: receiver,
                width: 48,
                height: 48,
                alignment: Alignment.topCenter,
                child: const Tooltip(
                  message: 'Receiver',
                  child: Icon(
                    Icons.radio,
                    color: Colors.blue,
                    size: 48,
                  ),
                ),
              ),
            );
          }

          final center = user ?? sender ?? receiver ?? _initialPosition;

          return Column(
            children: [
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
                    PolylineLayer(polylines: polylines),
                    if (sender != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: sender,
                            radius: 50,
                            useRadiusInMeter: true,
                            color: isDanger
                                ? Colors.red.withValues(alpha: 0.2)
                                : Colors.green.withValues(alpha: 0.2),
                            borderColor:
                                isDanger ? Colors.red : Colors.green,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    if (markers.isNotEmpty) MarkerLayer(markers: markers),
                  ],
                ),
              ),
              if (sender != null)
                _buildInfoPanel(
                  status: status,
                  latitude: sender.latitude,
                  longitude: sender.longitude,
                  speed: monitoring?.speed,
                  timestamp: monitoring?.timestamp,
                  zonaAmanLabel: zonaAmanLabel,
                  jarakLabel: jarakLabel,
                  safetyLevel: safetyLevel,
                )
              else
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Text(
                      user != null
                          ? 'Menunggu koordinat Sender...'
                          : 'Menunggu lokasi pengguna...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
