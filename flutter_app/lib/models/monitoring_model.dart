import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Model monitoring live (diisi dari Firebase Realtime Database).
class MonitoringModel {
  final String deviceId;
  final String status;
  final int distance;
  final int? battery;
  final int? signal;
  final double? latitude;
  final double? longitude;
  final double? receiverLatitude;
  final double? receiverLongitude;
  final double? speed;
  final int timestamp;
  final int? lastUpdate;
  final bool online;
  final bool hasData;
  final String? deviceType;
  final String? pairedSender;
  final String? pairedReceiver;
  final bool? alarm;
  final String? connectionStatus;

  /// Status koneksi dari Backend Device Status Engine (OFF/WAITING/CONNECTING/ONLINE).
  final String? linkStatus;

  /// Limit Switch dari ESP32 (HIGH/LOW) — digunakan oleh RuleBase.
  final String? limitSwitch;

  /// GPS data (lat/lng parsed as double? for direct use).
  final double? gpsLat;
  final double? gpsLng;

  const MonitoringModel({
    required this.deviceId,
    required this.status,
    required this.distance,
    required this.battery,
    required this.signal,
    required this.timestamp,
    this.lastUpdate,
    this.latitude,
    this.longitude,
    this.receiverLatitude,
    this.receiverLongitude,
    this.speed,
    this.online = false,
    this.hasData = false,
    this.deviceType,
    this.pairedSender,
    this.pairedReceiver,
    this.alarm,
    this.connectionStatus,
    this.linkStatus,
    this.limitSwitch,
    this.gpsLat,
    this.gpsLng,
  });

  factory MonitoringModel.noData({String? deviceId}) {
    return MonitoringModel(
      deviceId: deviceId ?? AppConstants.defaultDeviceId,
      status: SensorStatus.unknown,
      distance: 0,
      battery: null,
      signal: null,
      latitude: null,
      longitude: null,
      receiverLatitude: null,
      receiverLongitude: null,
      speed: null,
      timestamp: 0,
      lastUpdate: null,
      online: false,
      hasData: false,
      deviceType: null,
      pairedSender: null,
      pairedReceiver: null,
      alarm: null,
      connectionStatus: null,
      linkStatus: null,
      limitSwitch: null,
      gpsLat: null,
      gpsLng: null,
    );
  }

  factory MonitoringModel.fromMap(Map<dynamic, dynamic> map) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString());
    }

    double? parseReceiverLatitude(Map<dynamic, dynamic> source) {
      final direct = parseDouble(source['receiverLatitude']) ??
          parseDouble(source['receiver_lat']);
      if (direct != null) return direct;

      final receiverLocation = source['receiverLocation'];
      if (receiverLocation is Map) {
        return parseDouble(receiverLocation['latitude']) ??
            parseDouble(receiverLocation['lat']);
      }

      final receiver = source['receiver'];
      if (receiver is Map) {
        return parseDouble(receiver['latitude']) ??
            parseDouble(receiver['lat']);
      }
      return null;
    }

    double? parseReceiverLongitude(Map<dynamic, dynamic> source) {
      final direct = parseDouble(source['receiverLongitude']) ??
          parseDouble(source['receiver_lng']) ??
          parseDouble(source['receiverLng']) ??
          parseDouble(source['receiver_lon']);
      if (direct != null) return direct;

      final receiverLocation = source['receiverLocation'];
      if (receiverLocation is Map) {
        return parseDouble(receiverLocation['longitude']) ??
            parseDouble(receiverLocation['lng']) ??
            parseDouble(receiverLocation['lon']);
      }

      final receiver = source['receiver'];
      if (receiver is Map) {
        return parseDouble(receiver['longitude']) ??
            parseDouble(receiver['lng']);
      }
      return null;
    }

    // Parse GPS from nested 'gps' object if available
    double? gpsLat;
    double? gpsLng;
    final gps = map['gps'];
    if (gps is Map) {
      gpsLat = parseDouble(gps['latitude']) ?? parseDouble(gps['lat']);
      gpsLng = parseDouble(gps['longitude']) ??
          parseDouble(gps['lng']) ??
          parseDouble(gps['lon']);
    }

    // FIX: Also parse 'lat' and 'lng' at the top level if 'latitude'/'longitude' are null
    // This handles ESP32/backend data that uses 'lat'/'lng' keys directly
    double? lat = parseDouble(map['latitude']) ?? parseDouble(map['lat']);
    double? lng = parseDouble(map['longitude']) ??
        parseDouble(map['lng']) ??
        parseDouble(map['lon']);

    // FIX: Fallback to gpsLat/gpsLng if top-level lat/lng are still null
    lat ??= gpsLat;
    lng ??= gpsLng;

    final statusRaw = map['status']?.toString();

    return MonitoringModel(
      deviceId: map['deviceId']?.toString() ?? AppConstants.defaultDeviceId,
      status: SensorStatus.fromEsp32(statusRaw),
      distance: parseInt(map['distance']) ?? 0,
      battery: parseInt(map['battery']),
      signal: parseInt(map['signal']),
      latitude: lat,
      longitude: lng,
      receiverLatitude: parseReceiverLatitude(map),
      receiverLongitude: parseReceiverLongitude(map),
      speed: parseDouble(map['speed']),
      timestamp: parseInt(map['timestamp']) ?? 0,
      lastUpdate: parseInt(map['lastUpdate']) ?? parseInt(map['lastUpdated']),
      online: map['online'] == true,
      hasData: true,
      deviceType: map['deviceType']?.toString(),
      pairedSender: map['pairedSender']?.toString(),
      pairedReceiver: map['pairedReceiver']?.toString(),
      alarm: map['alarm'] == true,
      connectionStatus: map['connectionStatus']?.toString(),
      linkStatus: map['linkStatus']?.toString(),
      limitSwitch: map['limitSwitch']?.toString(),
      gpsLat: gpsLat,
      gpsLng: gpsLng,
    );
  }

  /// Effective timestamp for offline detection (ms).
  int get effectiveTimeMs {
    if (lastUpdate != null && lastUpdate! > 0) {
      return lastUpdate! < 1000000000000 ? lastUpdate! * 1000 : lastUpdate!;
    }
    if (timestamp > 0) {
      return timestamp < 1000000000000 ? timestamp * 1000 : timestamp;
    }
    return 0;
  }

  /// Convenient getter: get any available latitude
  double? get effectiveLatitude => latitude ?? gpsLat;

  /// Convenient getter: get any available longitude
  double? get effectiveLongitude => longitude ?? gpsLng;

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'status': status,
      'distance': distance,
      'battery': battery,
      'signal': signal,
      'latitude': latitude,
      'longitude': longitude,
      'receiverLatitude': receiverLatitude,
      'receiverLongitude': receiverLongitude,
      'speed': speed,
      'timestamp': timestamp,
      'online': online,
      if (linkStatus != null) 'linkStatus': linkStatus,
    };
  }

  MonitoringModel copyWith({
    String? deviceId,
    String? status,
    int? distance,
    int? battery,
    int? signal,
    double? latitude,
    double? longitude,
    double? receiverLatitude,
    double? receiverLongitude,
    double? speed,
    int? timestamp,
    bool? online,
    bool? hasData,
    String? linkStatus,
  }) {
    return MonitoringModel(
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      distance: distance ?? this.distance,
      battery: battery ?? this.battery,
      signal: signal ?? this.signal,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      receiverLatitude: receiverLatitude ?? this.receiverLatitude,
      receiverLongitude: receiverLongitude ?? this.receiverLongitude,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
      online: online ?? this.online,
      hasData: hasData ?? this.hasData,
      linkStatus: linkStatus ?? this.linkStatus,
    );
  }

  bool get isDanger =>
      status == SensorStatus.danger || status == AppConstants.statusDanger;
  bool get isUnknown => status == SensorStatus.unknown;

  DateTime get dateTime => Formatters.fromTimestamp(timestamp);
}
