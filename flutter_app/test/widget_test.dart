import 'package:flutter_test/flutter_test.dart';
import 'package:tracksafe_app/utils/constants.dart';
import 'package:tracksafe_app/utils/status_helper.dart';
import 'package:tracksafe_app/models/monitoring_model.dart';

void main() {
  group('SensorStatus', () {
    test('fromEsp32 parses live statuses', () {
      // NORMAL alias maps to SAFE sesuai arsitektur final
      expect(SensorStatus.fromEsp32('normal'), SensorStatus.safe);
      expect(SensorStatus.fromEsp32('SAFE'), SensorStatus.safe);
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

    test('fromMap parses limitSwitch and gps fields', () {
      final model = MonitoringModel.fromMap({
        'deviceId': 'receiver01',
        'status': 'SAFE',
        'distance': 200,
        'battery': 85,
        'signal': 30,
        'limitSwitch': 'LOW',
        'gps': {'latitude': -6.91, 'longitude': 107.60},
        'timestamp': 1752600000,
      });

      expect(model.status, SensorStatus.safe);
      expect(model.limitSwitch, 'LOW');
      expect(model.gpsLat, closeTo(-6.91, 0.001));
      expect(model.gpsLng, closeTo(107.60, 0.001));
      expect(model.hasData, isTrue);
    });
  });

  group('StatusHelper', () {
    test('titles for all display statuses', () {
      expect(StatusHelper.title('SAFE'), 'AMAN');
      expect(StatusHelper.title('NORMAL'), 'AMAN');
      expect(StatusHelper.title('NOISE'), 'NOISE TERDETEKSI');
      expect(StatusHelper.title('DANGER'), 'KERETA TERDETEKSI');
      expect(StatusHelper.title('UNKNOWN'), 'MENUNGGU DATA');
      expect(StatusHelper.title('OFFLINE'), 'SENDER OFFLINE');
    });
  });

  group('RuleBase', () {
    test('RULE 1: distance >150 cm → SAFE', () {
      expect(RuleBase.evaluate(distance: 200, limitSwitch: 'LOW'), 'SAFE');
      expect(RuleBase.evaluate(distance: 200, limitSwitch: 'HIGH'), 'SAFE');
      expect(RuleBase.evaluate(distance: 151, limitSwitch: null), 'SAFE');
    });

    test('RULE 2: distance <150 cm, limitSwitch LOW → NOISE', () {
      expect(RuleBase.evaluate(distance: 100, limitSwitch: 'LOW'), 'NOISE');
      expect(RuleBase.evaluate(distance: 0, limitSwitch: 'low'), 'NOISE');
    });

    test('RULE 3: distance <150 cm, limitSwitch HIGH → DANGER', () {
      expect(RuleBase.evaluate(distance: 100, limitSwitch: 'HIGH'), 'DANGER');
      expect(RuleBase.evaluate(distance: 0, limitSwitch: 'High'), 'DANGER');
    });

    test('color helpers', () {
      expect(RuleBase.statusColor('SAFE'), 'HIJAU');
      expect(RuleBase.statusColor('NOISE'), 'KUNING');
      expect(RuleBase.statusColor('DANGER'), 'MERAH');
    });

    test('siren only on DANGER', () {
      expect(RuleBase.isSirenOn('SAFE'), isFalse);
      expect(RuleBase.isSirenOn('NOISE'), isFalse);
      expect(RuleBase.isSirenOn('DANGER'), isTrue);
    });

    test('history log on NOISE and DANGER', () {
      expect(RuleBase.needsHistoryLog('SAFE'), isFalse);
      expect(RuleBase.needsHistoryLog('NOISE'), isTrue);
      expect(RuleBase.needsHistoryLog('DANGER'), isTrue);
    });
  });

  group('AppConstants', () {
    test('offline threshold is 15 seconds', () {
      expect(AppConstants.senderOfflineThresholdSec, 15);
    });

    test('distance threshold is 150 cm', () {
      expect(AppConstants.distanceThresholdCm, 150);
    });
  });
}
