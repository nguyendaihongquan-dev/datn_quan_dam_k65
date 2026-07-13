/// Cấu hình chung cho MQTT và Firebase Realtime Database.
class AppConfig {
  AppConfig._();

  // MQTT broker (HiveMQ Cloud)
  static const String mqttBrokerId = 'b244e8ff9c534d3ebd90d41438747065';
  static const String mqttHost =
      'b244e8ff9c534d3ebd90d41438747065.s1.eu.hivemq.cloud';
  static const int mqttTlsPort = 8883;
  static const int mqttWebSocketPort = 8884;
  static const String mqttUsername = 'quantest';
  static const String mqttPassword = '12345678';

  // MQTT topics
  static const String electricTopic = 'electric';
  static const String relayTopic = 'relay';

  // Firebase Realtime Database
  static const String databaseUrl =
      'https://datn-cuan-default-rtdb.firebaseio.com';

  /// Đường dẫn lưu trạng thái relay trên Firebase RTDB.
  static const String relayFirebasePath = 'ev_charging/relay';

  /// Trạng thái mặc định khi chưa có dữ liệu trên Firebase (false = tắt).
  static const bool relayDefaultState = false;
}
