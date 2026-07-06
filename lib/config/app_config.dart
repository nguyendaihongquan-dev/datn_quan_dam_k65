/// Cấu hình chung cho MQTT và Firebase Realtime Database.
class AppConfig {
  AppConfig._();

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
