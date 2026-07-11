import 'package:flutter_test/flutter_test.dart';
import 'package:ev_charging_station/models/electric_data.dart';

void main() {
  group('ElectricData', () {
    test('fromJson parses unified electric payload', () {
      final data = ElectricData.fromJson({
        'voltage': 223.8,
        'current': 8.92,
        'power': 1990.5,
        'energy': 2.753,
        'frequency': 50.0,
        'pf': 0.95,
        'temperature': 29.5,
        'humidity': 68.0,
        'relay_command': 1,
        'relay': 1,
        'buzzer': 0,
        'temperature_alarm': 0,
        'pzem_valid': 1,
        'dht_valid': 1,
        'rtc_valid': 1,
        'wifi': 1,
        'mqtt': 1,
        'date': '2026-07-11',
        'time': '15:12:42',
      });

      expect(data.voltage, 223.8);
      expect(data.current, 8.92);
      expect(data.power, 1990.5);
      expect(data.energy, 2.753);
      expect(data.frequency, 50.0);
      expect(data.pf, 0.95);
      expect(data.temperature, 29.5);
      expect(data.humidity, 68.0);
      expect(data.relayOn, isTrue);
      expect(data.dateLabel, '2026-07-11');
      expect(data.timeLabel, '15:12:42');
      expect(data.pzemValid, 1);
      expect(data.dhtValid, 1);
      expect(data.rtcValid, 1);
    });

    test('fromJson supports legacy hour and minute fields', () {
      final data = ElectricData.fromJson({
        'voltage': 220,
        'current': 0,
        'power': 0,
        'energy': 0,
        'hour': 15,
        'minute': 28,
      });

      expect(data.timeLabel, '15:28:00');
    });

    test('isCharging is true when current > 0.1', () {
      final data = ElectricData.fromJson({
        'voltage': 220,
        'current': 0.11,
        'power': 0,
        'energy': 0,
      });
      expect(data.isCharging, isTrue);
    });

    test('hasAlarm uses temperature_alarm and buzzer', () {
      final alarm = ElectricData.fromJson({
        'voltage': 220,
        'current': 0,
        'power': 0,
        'energy': 0,
        'temperature_alarm': 1,
      });
      final buzzer = ElectricData.fromJson({
        'voltage': 220,
        'current': 0,
        'power': 0,
        'energy': 0,
        'buzzer': 1,
      });

      expect(alarm.hasAlarm, isTrue);
      expect(buzzer.hasAlarm, isTrue);
    });

    test('placeholder is idle state', () {
      final data = ElectricData.placeholder();
      expect(data.isCharging, isFalse);
      expect(data.hasAlarm, isFalse);
      expect(data.statusLabel, 'Chờ kết nối');
    });
  });
}
