import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Entri history (diisi mulai TAHAP 2+ dari Firebase `/history`).
class HistoryModel {
  final String id;
  final String deviceId;
  final String status;
  final int distance;
  final int? battery;
  final int? signal;
  final int timestamp;
  final bool isAcknowledged;
  final int? ackTime;

  const HistoryModel({
    required this.id,
    required this.deviceId,
    required this.status,
    required this.distance,
    required this.battery,
    required this.signal,
    required this.timestamp,
    this.isAcknowledged = false,
    this.ackTime,
  });

  factory HistoryModel.fromMap(Map<dynamic, dynamic> map, {String? id}) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString());
    }

    return HistoryModel(
      id: id ?? map['id']?.toString() ?? '0',
      deviceId: map['deviceId']?.toString() ?? AppConstants.defaultDeviceId,
      status: SensorStatus.fromEsp32(map['status']?.toString()),
      distance: parseInt(map['distance']) ?? 0,
      battery: parseInt(map['battery']),
      signal: parseInt(map['signal']),
      timestamp: parseInt(map['timestamp']) ?? 0,
      isAcknowledged: map['isAcknowledged'] == true,
      ackTime: parseInt(map['ackTime']),
    );
  }

  String get dateLabel => Formatters.date(timestamp);
  String get timeLabel => Formatters.time(timestamp);
}
