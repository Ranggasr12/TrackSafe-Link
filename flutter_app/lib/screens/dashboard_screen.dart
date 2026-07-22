import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/history_model.dart';
import '../models/monitoring_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/device_pairing_provider.dart';
import '../providers/monitoring_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/system_labels.dart';

/// Dashboard — tampilan utama TrackSafe.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _initialized = false;
  LatLng? _phonePosition;
  StreamSubscription<Position>? _workerSubscription;
  String _currentTime = '';
  Timer? _clockTimer;
  bool _workerReady = false;
  bool _phoneGpsAvailable = false;
  bool _gpsDialogShown = false;

  @override
  void initState() {
    super.initState();
    _startWorkerTracking();
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateFormat('HH:mm:ss', 'id_ID').format(DateTime.now());
    });
  }

  @override
  void dispose() {
    _workerSubscription?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _startWorkerTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Tampilkan dialog minta user mengaktifkan GPS
      if (!_gpsDialogShown && mounted) {
        _gpsDialogShown = true;
        _showEnableGpsDialog();
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _phonePosition = LatLng(current.latitude, current.longitude);
        _phoneGpsAvailable = true;
        _workerReady = true;
      });
    } catch (_) {
      // GPS gagal — Worker tidak akan tampil
      if (!mounted) return;
      setState(() {
        _phoneGpsAvailable = false;
        _workerReady = true;
      });
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    _workerSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _phonePosition = LatLng(position.latitude, position.longitude);
        _phoneGpsAvailable = true;
        _workerReady = true;
      });
    });
  }

  void _showEnableGpsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktifkan GPS'),
        content: const Text(
          'Fitur Worker membutuhkan GPS untuk melacak posisi Anda. '
          'Silakan aktifkan GPS di pengaturan.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
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

  /// Cek apakah Sender ONLINE berdasarkan linkStatus dari Firebase.
  bool _isSenderOnline(MonitoringModel? monitoring) {
    if (monitoring == null || !monitoring.hasData) return false;
    final linkStatus = monitoring.linkStatus?.toUpperCase().trim();
    return linkStatus == 'ONLINE';
  }

  /// Cek apakah Receiver ONLINE berdasarkan linkStatus dari Firebase.
  bool _isReceiverOnline(MonitoringModel? receiverNode) {
    if (receiverNode == null || !receiverNode.hasData) return false;
    final linkStatus = receiverNode.linkStatus?.toUpperCase().trim();
    return linkStatus == 'ONLINE';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<MonitoringProvider, AppStateProvider,
        DevicePairingProvider>(
      builder: (context, monProv, appState, pairing, child) {
        final monitoring = monProv.monitoring;
        final status = monProv.currentStatus;
        final isOffline = status == SensorStatus.offline;
        final isDanger = status == SensorStatus.danger;
        final isNoise = status == SensorStatus.noise;
        final isSafe =
            status == SensorStatus.safe || status == SensorStatus.normal;

        // Sender: hanya tampil jika ONLINE (linkStatus == ONLINE)
        LatLng? senderPosition;
        if (_isSenderOnline(monitoring)) {
          final lat = monitoring!.effectiveLatitude;
          final lng = monitoring.effectiveLongitude;
          if (lat != null && lng != null) {
            senderPosition = LatLng(lat, lng);
          }
        }

        // Receiver: hanya tampil jika ONLINE (linkStatus == ONLINE)
        LatLng? receiverPosition;
        final receiverNode = pairing.receiverTelemetry;
        if (_isReceiverOnline(receiverNode)) {
          final lat = receiverNode!.effectiveLatitude;
          final lng = receiverNode.effectiveLongitude;
          if (lat != null && lng != null) {
            receiverPosition = LatLng(lat, lng);
          }
        }
        // Fallback ke nested receiver coords di sender (hanya jika receiver ONLINE)
        if (receiverPosition == null && _isReceiverOnline(monitoring)) {
          if (monitoring!.receiverLatitude != null &&
              monitoring.receiverLongitude != null) {
            receiverPosition = LatLng(
              monitoring.receiverLatitude!,
              monitoring.receiverLongitude!,
            );
          }
        }

        // Worker: hanya tampil jika GPS phone benar-benar tersedia
        // JANGAN gunakan Sender sebagai fallback Worker
        final LatLng? workerPosition =
            _phoneGpsAvailable ? _phonePosition : null;

        final today = DateTime.now();
        final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(today);

        return RefreshIndicator(
          onRefresh: () => monProv.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ===== HEADER =====
              _HeaderCard(
                date: dateStr,
                time: _currentTime,
                status: status,
              ),
              const SizedBox(height: 12),

              // ===== SYSTEM STATUS =====
              _StatusCard(
                backendLabel: appState.backendLabel,
                firebaseLabel: appState.firebaseLabel,
                senderLabel: appState.senderLabel,
                receiverLabel: appState.receiverLabel,
                pairingLabel: pairing.isPaired ? 'PAIRED' : 'NOT PAIRED',
                lastUpdate: monitoring?.timestamp ?? 0,
              ),
              const SizedBox(height: 12),

              // ===== KONDISI =====
              _KondisiCard(
                status: status,
                distance: monProv.displayDistance,
                limitSwitch: monitoring?.limitSwitch,
                isOffline: isOffline,
                isDanger: isDanger,
                isNoise: isNoise,
                isSafe: isSafe,
              ),
              const SizedBox(height: 12),

              // ===== MAP =====
              _MapCard(
                workerPosition: workerPosition,
                senderPosition: senderPosition,
                receiverPosition: receiverPosition,
                status: status,
                isDanger: isDanger,
                isOffline: isOffline,
                receiverIsOffline: receiverNode != null &&
                    receiverNode.hasData &&
                    !_isReceiverOnline(receiverNode),
                workerReady: _workerReady,
              ),
              const SizedBox(height: 12),

              // ===== DEVICE STATUS =====
              _DeviceInfoCard(
                senderBattery: monitoring?.battery,
                senderSignal: monitoring?.signal,
                senderLastSeen: monitoring?.timestamp ?? 0,
                senderLinkStatus: monitoring?.linkStatus,
                receiverBattery: receiverNode?.battery,
                receiverSignal: receiverNode?.signal,
                receiverLastSeen: receiverNode?.timestamp ?? 0,
                receiverLinkStatus: receiverNode?.linkStatus,
                senderId: pairing.senderId,
                receiverId: pairing.receiverId,
              ),
              const SizedBox(height: 12),

              // ===== STATISTICS =====
              _QuickStatsCard(history: appState.history),
              const SizedBox(height: 12),

              // ===== ALARM HISTORY =====
              _AlarmHistoryCard(history: appState.history),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// HEADER
// =====================================================================
class _HeaderCard extends StatelessWidget {
  final String date;
  final String time;
  final String status;

  const _HeaderCard({
    required this.date,
    required this.time,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = status == SensorStatus.danger;
    final isOffline = status == SensorStatus.offline;

    Color headerColor = AppColors.primary;
    if (isDanger) headerColor = AppColors.danger;
    if (isOffline) headerColor = AppColors.offline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [headerColor, headerColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TrackSafe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SYSTEM STATUS
// =====================================================================
class _StatusCard extends StatelessWidget {
  final String backendLabel;
  final String firebaseLabel;
  final String senderLabel;
  final String receiverLabel;
  final String pairingLabel;
  final int lastUpdate;

  const _StatusCard({
    required this.backendLabel,
    required this.firebaseLabel,
    required this.senderLabel,
    required this.receiverLabel,
    required this.pairingLabel,
    required this.lastUpdate,
  });

  Color _statusColor(String label) {
    final v = label.toUpperCase().trim();
    if (v == 'ONLINE' || v == 'CONNECTED' || v == 'PAIRED') return Colors.green;
    if (v == 'OFFLINE' || v == 'NOT PAIRED' || v == 'OFF') return Colors.red;
    if (v == 'CHECKING' || v == 'WAITING' || v == 'CONNECTING') {
      return Colors.orange;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastUpdateStr = lastUpdate > 0
        ? Formatters.dateTime(lastUpdate)
        : SystemLabels.placeholder;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'SYSTEM STATUS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _statusItem('Backend', backendLabel),
            _statusItem('Firebase', firebaseLabel),
            _statusItem('Sender', senderLabel),
            _statusItem('Receiver', receiverLabel),
            _statusItem('Pairing', pairingLabel),
            _statusItem('Last Update', lastUpdateStr),
          ],
        ),
      ),
    );
  }

  Widget _statusItem(String label, String value) {
    final color = _statusColor(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// KONDISI
// =====================================================================
class _KondisiCard extends StatelessWidget {
  final String status;
  final int? distance;
  final String? limitSwitch;
  final bool isOffline;
  final bool isDanger;
  final bool isNoise;
  final bool isSafe;

  const _KondisiCard({
    required this.status,
    required this.distance,
    this.limitSwitch,
    required this.isOffline,
    required this.isDanger,
    required this.isNoise,
    required this.isSafe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor = AppColors.normal;
    String statusText = 'SAFE';
    IconData statusIcon = Icons.check_circle;

    if (isDanger) {
      statusColor = AppColors.danger;
      statusText = 'DANGER';
      statusIcon = Icons.emergency;
    } else if (isNoise) {
      statusColor = AppColors.noise;
      statusText = 'NOISE';
      statusIcon = Icons.warning_amber_rounded;
    } else if (isOffline) {
      statusColor = AppColors.offline;
      statusText = 'OFFLINE';
      statusIcon = Icons.cloud_off;
    } else if (isSafe) {
      statusColor = AppColors.normal;
      statusText = 'SAFE';
      statusIcon = Icons.check_circle;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'KONDISI',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Status badge
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Detail
            Row(
              children: [
                _detailItem(
                    'Distance', distance != null ? '$distance cm' : '--'),
                const SizedBox(width: 16),
                _detailItem('Limit Switch', _limitSwitchLabel()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _limitSwitchLabel() {
    if (limitSwitch == null) return '--';
    final v = limitSwitch!.toUpperCase().trim();
    if (v == 'HIGH') return 'HIGH';
    if (v == 'LOW') return 'LOW';
    return limitSwitch!;
  }

  Widget _detailItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// OFFLINE DETECTOR
// =====================================================================
class OfflineDetector {
  static const int _offlineThresholdSec = 15;

  static bool isOffline(MonitoringModel model) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = model.effectiveTimeMs;
    if (last <= 0) return true;
    return (now - last) > (_offlineThresholdSec * 1000);
  }
}

// =====================================================================
// MAP
// =====================================================================
class _MapCard extends StatefulWidget {
  final LatLng? workerPosition;
  final LatLng? senderPosition;
  final LatLng? receiverPosition;
  final String status;
  final bool isDanger;
  final bool isOffline;
  final bool receiverIsOffline;
  final bool workerReady;

  const _MapCard({
    required this.workerPosition,
    required this.senderPosition,
    required this.receiverPosition,
    required this.status,
    required this.isDanger,
    required this.isOffline,
    this.receiverIsOffline = false,
    this.workerReady = false,
  });

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  static const LatLng _defaultPosition = LatLng(-6.914744, 107.609810);
  static const double _defaultZoom = 15.0;
  bool _hasAutoFocused = false;
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Auto-focus dengan prioritas: Worker → Sender → Receiver → Default
  /// Hanya fokus jika marker tujuan benar-benar tersedia.
  void _tryAutoFocus() {
    if (_hasAutoFocused) return;

    // Cari titik dengan prioritas — hanya jika benar-benar tersedia
    LatLng? target;
    if (widget.workerPosition != null) {
      target = widget.workerPosition;
    } else if (widget.senderPosition != null) {
      target = widget.senderPosition;
    } else if (widget.receiverPosition != null) {
      target = widget.receiverPosition;
    }

    if (target == null) return;

    _hasAutoFocused = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(target!, _defaultZoom);
    });
  }

  void _focusMarkers() {
    final points = <LatLng>[
      if (widget.workerPosition != null) widget.workerPosition!,
      if (widget.senderPosition != null) widget.senderPosition!,
      if (widget.receiverPosition != null) widget.receiverPosition!,
    ];
    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, _defaultZoom);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(60),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _MapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger auto-focus when any position becomes available
    if (!_hasAutoFocused) {
      final hadAnyBefore = oldWidget.workerPosition != null ||
          oldWidget.senderPosition != null ||
          oldWidget.receiverPosition != null;
      final hasAnyNow = widget.workerPosition != null ||
          widget.senderPosition != null ||
          widget.receiverPosition != null;
      if (!hadAnyBefore && hasAnyNow) {
        _tryAutoFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _tryAutoFocus();

    final markers = <Marker>[];

    // ===== WORKER MARKER — Biru, Icon Person =====
    // Hanya tampil jika GPS phone tersedia
    if (widget.workerPosition != null) {
      markers.add(
        Marker(
          point: widget.workerPosition!,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_pin_circle,
                color: Colors.blue, size: 40),
          ),
        ),
      );
    }

    // ===== SENDER MARKER — Merah, Icon Train (blink if DANGER) =====
    // Hanya tampil jika Sender ONLINE (linkStatus == ONLINE)
    if (widget.senderPosition != null) {
      final senderColor = widget.isDanger
          ? Colors.red
          : widget.isOffline
              ? Colors.grey
              : Colors.red;
      markers.add(
        Marker(
          point: widget.senderPosition!,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: widget.isDanger
              ? AnimatedBuilder(
                  animation: _blinkController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.3 + (_blinkController.value * 0.7),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: const Icon(Icons.train, color: Colors.red, size: 40),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: senderColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.train, color: senderColor, size: 40),
                ),
        ),
      );
    }

    // ===== RECEIVER MARKER — Hijau, Icon Radio (grey if offline) =====
    // Hanya tampil jika Receiver ONLINE (linkStatus == ONLINE)
    if (widget.receiverPosition != null) {
      final receiverColor =
          widget.receiverIsOffline ? Colors.grey : Colors.green;
      markers.add(
        Marker(
          point: widget.receiverPosition!,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: receiverColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.radio, color: receiverColor, size: 36),
          ),
        ),
      );
    }

    // Polyline: Worker → Sender
    final polylines = <Polyline>[];
    if (widget.workerPosition != null && widget.senderPosition != null) {
      polylines.add(
        Polyline(
          points: [widget.workerPosition!, widget.senderPosition!],
          strokeWidth: 3,
          color: Colors.orange.withValues(alpha: 0.7),
        ),
      );
    }

    // Polyline: Sender → Receiver
    if (widget.senderPosition != null && widget.receiverPosition != null) {
      polylines.add(
        Polyline(
          points: [widget.senderPosition!, widget.receiverPosition!],
          strokeWidth: 3,
          color: Colors.blue.withValues(alpha: 0.7),
        ),
      );
    }

    // Priority untuk initialCenter: Worker → Sender → Receiver → Default
    final center = widget.workerPosition ??
        widget.senderPosition ??
        widget.receiverPosition ??
        _defaultPosition;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _defaultZoom,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tracksafe.tracksafe_app',
                ),
                if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
            // Map title + legend
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MAP',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 Worker  🚂 Sender  📡 Receiver',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
            // Focus button
            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'focus_map',
                onPressed: _focusMarkers,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// DEVICE STATUS — Realtime dari Firebase Stream
// =====================================================================
class _DeviceInfoCard extends StatelessWidget {
  final int? senderBattery;
  final int? senderSignal;
  final int senderLastSeen;
  final String? senderLinkStatus;
  final int? receiverBattery;
  final int? receiverSignal;
  final int receiverLastSeen;
  final String? receiverLinkStatus;
  final String? senderId;
  final String? receiverId;

  const _DeviceInfoCard({
    required this.senderBattery,
    required this.senderSignal,
    required this.senderLastSeen,
    this.senderLinkStatus,
    required this.receiverBattery,
    required this.receiverSignal,
    required this.receiverLastSeen,
    this.receiverLinkStatus,
    this.senderId,
    this.receiverId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senderSeen = _formatLastSeen(senderLastSeen);
    final receiverSeen = _formatLastSeen(receiverLastSeen);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'DEVICE STATUS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Sender
            _deviceRow(
              icon: Icons.sensors,
              title: 'Sender${senderId != null ? ' ($senderId)' : ''}',
              battery: senderBattery,
              signal: senderSignal,
              lastSeen: senderSeen,
              linkStatus: senderLinkStatus,
            ),
            const Divider(height: 20),
            // Receiver
            _deviceRow(
              icon: Icons.router,
              title: 'Receiver${receiverId != null ? ' ($receiverId)' : ''}',
              battery: receiverBattery,
              signal: receiverSignal,
              lastSeen: receiverSeen,
              linkStatus: receiverLinkStatus,
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(int timestamp) {
    if (timestamp <= 0) return '—';
    return Formatters.dateTime(timestamp);
  }

  Widget _deviceRow({
    required IconData icon,
    required String title,
    required int? battery,
    required int? signal,
    required String lastSeen,
    String? linkStatus,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              // Gunakan Wrap agar chip tidak overflow
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _metricChip(Icons.battery_std, _batteryDisplay(battery)),
                  _metricChip(
                      Icons.signal_cellular_alt, _signalDisplay(signal)),
                  _metricChip(Icons.schedule, lastSeen),
                  if (linkStatus != null) _metricChip(Icons.link, linkStatus),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tampilkan '—' jika battery null atau ≤ 0 (belum ada data).
  String _batteryDisplay(int? battery) {
    if (battery == null || battery <= 0) return '—';
    return '$battery%';
  }

  /// Tampilkan '—' jika signal null atau ≤ 0 (belum ada data).
  String _signalDisplay(int? signal) {
    if (signal == null || signal <= 0) return '—';
    return '$signal';
  }

  Widget _metricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// STATISTICS
// =====================================================================
class _QuickStatsCard extends StatelessWidget {
  final List<HistoryModel> history;

  const _QuickStatsCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayStart =
        DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;

    // System event types yang HARUS dikecualikan (sama dengan HistoryScreen & StatisticsScreen)
    const systemEvents = <String>{
      'ONLINE',
      'OFFLINE',
      'PAIR',
      'UNPAIR',
      'PAIRING',
      'UNPAIRING',
      'CONNECT',
      'DISCONNECT',
      'CONNECTED',
      'DISCONNECTED',
      'BACKEND_RESTART',
      'SERVER_START',
      'DEVICE_REGISTER',
      'HEARTBEAT',
      'GPS_UPDATE',
      'BATTERY',
      'SIGNAL',
      'MQTT_CONNECTED',
      'MQTT_DISCONNECTED',
      'SYSTEM',
      'BATTERY_UPDATE',
      'SIGNAL_UPDATE',
      'BACKEND_ONLINE',
      'BACKEND_OFFLINE',
    };
    // Filter sama dengan HistoryScreen & StatisticsScreen:
    // eventType bukan sistem, status hanya SAFE/NOISE/DANGER
    final todayItems = history.where((h) {
      final s = h.status.toString().toUpperCase().trim();
      if (s != 'SAFE' && s != 'NOISE' && s != 'DANGER') return false;
      final et = h.eventType.toString().toUpperCase().trim();
      if (systemEvents.contains(et)) return false;
      final ts = h.timestamp < 1000000000000 ? h.timestamp * 1000 : h.timestamp;
      return ts >= todayStart;
    }).toList();

    int safe = 0, noise = 0, danger = 0;
    for (final item in todayItems) {
      final s = item.status.toString().toUpperCase().trim();
      if (s == 'SAFE') safe++;
      if (s == 'NOISE') noise++;
      if (s == 'DANGER') danger++;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'STATISTICS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statItem('SAFE', '$safe', Colors.green, Icons.check_circle),
                const SizedBox(width: 8),
                _statItem('NOISE', '$noise', Colors.orange,
                    Icons.warning_amber_rounded),
                const SizedBox(width: 8),
                _statItem('DANGER', '$danger', Colors.red, Icons.emergency),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ALARM HISTORY — hanya SAFE, NOISE, DANGER
// =====================================================================
class _AlarmHistoryCard extends StatelessWidget {
  final List<HistoryModel> history;

  const _AlarmHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // System event types yang HARUS dikecualikan (sama dengan HistoryScreen & StatisticsScreen)
    const systemEvents = <String>{
      'ONLINE',
      'OFFLINE',
      'PAIR',
      'UNPAIR',
      'PAIRING',
      'UNPAIRING',
      'CONNECT',
      'DISCONNECT',
      'CONNECTED',
      'DISCONNECTED',
      'BACKEND_RESTART',
      'SERVER_START',
      'DEVICE_REGISTER',
      'HEARTBEAT',
      'GPS_UPDATE',
      'BATTERY',
      'SIGNAL',
      'MQTT_CONNECTED',
      'MQTT_DISCONNECTED',
      'SYSTEM',
      'BATTERY_UPDATE',
      'SIGNAL_UPDATE',
      'BACKEND_ONLINE',
      'BACKEND_OFFLINE',
    };
    // Filter sama dengan HistoryScreen & StatisticsScreen:
    // eventType bukan sistem, status hanya SAFE/NOISE/DANGER
    final alarmEvents = history.where((item) {
      final s = item.status.toString().toUpperCase().trim();
      if (s != 'SAFE' && s != 'NOISE' && s != 'DANGER') return false;
      final et = item.eventType.toString().toUpperCase().trim();
      if (systemEvents.contains(et)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Ambil 5 terbaru
    final latestAlarms = alarmEvents.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alarm, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ALARM HISTORY',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (latestAlarms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Belum ada riwayat',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              )
            else
              ...latestAlarms.map((item) => _historyItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(dynamic item) {
    final rawStatus = item.status?.toString().toUpperCase() ?? '';
    final status = rawStatus == 'NORMAL' ? 'SAFE' : rawStatus;
    final timeLabel = item.timeLabel?.toString() ?? '';

    Color dotColor = Colors.grey;
    if (status == 'DANGER') dotColor = Colors.red;
    if (status == 'NOISE') dotColor = Colors.orange;
    if (status == 'SAFE') dotColor = Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              timeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
