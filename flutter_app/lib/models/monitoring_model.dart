import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Model monitoring live (diisi mulai TAHAP 2+ dari Firebase).
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
  final bool online;
  final bool hasData;

  const MonitoringModel({
    required this.deviceId,
    required this.status,
    required this.distance,
    required this.battery,
    required this.signal,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.receiverLatitude,
    this.receiverLongitude,
    this.speed,
    this.online = false,
    this.hasData = false,
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
      online: false,
      hasData: false,
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

    return MonitoringModel(
      deviceId: map['deviceId']?.toString() ?? AppConstants.defaultDeviceId,
      status: SensorStatus.fromEsp32(map['status']?.toString()),
      distance: parseInt(map['distance']) ?? 0,
      battery: parseInt(map['battery']),
      signal: parseInt(map['signal']),
      latitude: parseDouble(map['latitude']),
      longitude: parseDouble(map['longitude']),
      receiverLatitude: parseReceiverLatitude(map),
      receiverLongitude: parseReceiverLongitude(map),
      speed: parseDouble(map['speed']),
      timestamp: parseInt(map['timestamp']) ?? 0,
      online: map['online'] == true,
      hasData: true,
    );
  }

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
    );
  }

  bool get isDanger => status == SensorStatus.danger;
  bool get isUnknown => status == SensorStatus.unknown;

  DateTime get dateTime => Formatters.fromTimestamp(timestamp);
}
