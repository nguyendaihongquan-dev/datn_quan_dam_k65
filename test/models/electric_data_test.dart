import 'package:flutter_test/flutter_test.dart';
import 'package:ev_charging_station/models/electric_data.dart';

void main() {
  group('ElectricData', () {
    test('fromJson parses numeric fields', () {
      final data = ElectricData.fromJson({
        'voltage': 223.8,
        'current': 8.92,
        'power': 2.0,
        'energy': 2.753,
        'alarm': 0,
        'hour': 15,
        'minute': 28,
      });

      expect(data.voltage, 223.8);
      expect(data.current, 8.92);
      expect(data.power, 2.0);
      expect(data.energy, 2.753);
      expect(data.hour, 15);
      expect(data.minute, 28);
    });

    test('isCharging is true when current > 0.1', () {
      const data = ElectricData(
        voltage: 220,
        current: 0.11,
        power: 0,
        energy: 0,
        alarm: 0,
        hour: 0,
        minute: 0,
      );
      expect(data.isCharging, isTrue);
    });

    test('isCharging is true when power > 0.05 even if current is low', () {
      const data = ElectricData(
        voltage: 220,
        current: 0,
        power: 0.06,
        energy: 0,
        alarm: 0,
        hour: 0,
        minute: 0,
      );
      expect(data.isCharging, isTrue);
    });

    test('isCharging is false for placeholder idle values', () {
      final data = ElectricData.placeholder();
      expect(data.isCharging, isFalse);
      expect(data.hasAlarm, isFalse);
      expect(data.statusLabel, 'Chờ kết nối');
    });

    test('statusLabel reflects alarm and charging', () {
      const charging = ElectricData(
        voltage: 220,
        current: 10,
        power: 2.2,
        energy: 1,
        alarm: 0,
        hour: 12,
        minute: 0,
      );
      const alarm = ElectricData(
        voltage: 220,
        current: 8,
        power: 1.8,
        energy: 1,
        alarm: 1,
        hour: 12,
        minute: 0,
      );

      expect(charging.statusLabel, 'Đang sạc');
      expect(alarm.statusLabel, 'Cảnh báo');
    });
  });
}
