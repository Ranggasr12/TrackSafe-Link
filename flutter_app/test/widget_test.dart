import 'package:flutter_test/flutter_test.dart';
import 'package:tracksafe_app/utils/constants.dart';
import 'package:tracksafe_app/utils/status_helper.dart';
import 'package:tracksafe_app/models/monitoring_model.dart';

void main() {
  group('SensorStatus', () {
    test('fromEsp32 parses live statuses', () {
      expect(SensorStatus.fromEsp32('normal'), SensorStatus.normal);
      expect(SensorStatus.fromEsp32('NOISE'), SensorStatus.noise);
      expect(SensorStatus.fromEsp32('Danger'), SensorStatus.danger);
    });

    test('fromEsp32 does not invent NORMAL', () {
      expect(SensorStatus.fromEsp32(null), SensorStatus.unknown);
      expect(SensorStatus.fromEsp32(''), SensorStatus.unknown);
      expect(SensorStatus.fromEsp32('INVALID'), SensorStatus.unknown);
    });
  });

  group('MonitoringModel', () {
    test('noData uses UNKNOWN without fake battery/signal', () {
      final model = MonitoringModel.noData(deviceId: 'sender01');
      expect(model.status, SensorStatus.unknown);
      expect(model.hasData, isFalse);
      expect(model.battery, isNull);
      expect(model.signal, isNull);
      expect(model.online, isFalse);
    });

    test('fromMap parses ESP32 payload', () {
      final model = MonitoringModel.fromMap({
        'deviceId': 'sender01',
        'status': 'DANGER',
        'distance': 340,
        'battery': 91,
        'signal': 24,
        'timestamp': 1752600000,
      });

      expect(model.deviceId, 'sender01');
      expect(model.status, SensorStatus.danger);
      expect(model.distance, 340);
      expect(model.battery, 91);
      expect(model.hasData, isTrue);
      expect(model.isDanger, isTrue);
    });
  });

  group('StatusHelper', () {
    test('titles for all display statuses', () {
      expect(StatusHelper.title('NORMAL'), 'AMAN');
      expect(StatusHelper.title('NOISE'), 'NOISE TERDETEKSI');
      expect(StatusHelper.title('DANGER'), 'KERETA TERDETEKSI');
      expect(StatusHelper.title('UNKNOWN'), 'MENUNGGU DATA');
      expect(StatusHelper.title('OFFLINE'), 'SENDER OFFLINE');
    });
  });
}
