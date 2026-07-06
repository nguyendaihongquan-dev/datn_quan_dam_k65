import 'package:flutter_test/flutter_test.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_state.dart';

void main() {
  group('MqttMessageReceived', () {
    test('duplicate payload with different sequence are not equal', () {
      const first = MqttMessageReceived(
        topic: 'electric',
        message: '{"current":0}',
        sequence: 0,
      );
      const second = MqttMessageReceived(
        topic: 'electric',
        message: '{"current":0}',
        sequence: 1,
      );

      expect(first, isNot(equals(second)));
    });
  });
}
