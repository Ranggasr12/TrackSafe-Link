import 'package:intl/intl.dart';

/// Helper format tanggal/jam & angka untuk UI.
class Formatters {
  Formatters._();

  static final DateFormat _date = DateFormat('dd MMM yyyy', 'id_ID');
  static final DateFormat _time = DateFormat('HH:mm:ss', 'id_ID');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy • HH:mm:ss', 'id_ID');
  static final DateFormat _shortDate = DateFormat('dd/MM/yy', 'id_ID');
  static final DateFormat _chartDay = DateFormat('dd/MM', 'id_ID');

  /// Timestamp bisa dalam detik (ESP32) atau milidetik.
  static DateTime fromTimestamp(int timestamp) {
    if (timestamp <= 0) return DateTime.now();
    // Detik Unix ~10 digit, milidetik ~13 digit
    if (timestamp < 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static int toEpochMillis(DateTime dt) => dt.millisecondsSinceEpoch;

  static String date(int timestamp) => _date.format(fromTimestamp(timestamp));

  static String time(int timestamp) => _time.format(fromTimestamp(timestamp));

  static String dateTime(int timestamp) =>
      _dateTime.format(fromTimestamp(timestamp));

  static String shortDate(int timestamp) =>
      _shortDate.format(fromTimestamp(timestamp));

  static String chartDay(DateTime dt) => _chartDay.format(dt);

  static String relative(int timestamp) {
    final dt = fromTimestamp(timestamp);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}d lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays} hari lalu';
  }

  static String battery(int? percent) {
    if (percent == null) return '--';
    return '$percent%';
  }

  static String signal(int? value) {
    if (value == null) return '--';
    // ESP32 bisa kirim RSSI negatif atau kualitas positif
    if (value < 0) return '$value dBm';
    return '$value';
  }

  static String distance(int? cm, {bool available = true}) {
    if (!available || cm == null) return '--';
    return '$cm cm';
  }

  static const String noDataLabel = 'Belum ada data';
}
