class ElectricData {
  final double voltage;
  final double current;
  final double power;
  final double energy;
  final int alarm;
  final int hour;
  final int minute;

  const ElectricData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.energy,
    required this.alarm,
    required this.hour,
    required this.minute,
  });

  factory ElectricData.fromJson(Map<String, dynamic> json) => ElectricData(
    voltage: (json['voltage'] as num?)?.toDouble() ?? 0,
    current: (json['current'] as num?)?.toDouble() ?? 0,
    power: (json['power'] as num?)?.toDouble() ?? 0,
    energy: (json['energy'] as num?)?.toDouble() ?? 0,
    alarm: json['alarm'] ?? 0,
    hour: json['hour'] ?? 0,
    minute: json['minute'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'voltage': voltage,
    'current': current,
    'power': power,
    'energy': energy,
    'alarm': alarm,
    'hour': hour,
    'minute': minute,
  };

  bool get isCharging => current > 0.1;
  bool get hasAlarm => alarm != 0;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get statusLabel {
    if (hasAlarm) return 'Cảnh báo';
    if (isCharging) return 'Đang sạc';
    return 'Chờ kết nối';
  }

  /// Dữ liệu mặc định khi không nhận được tín hiệu từ MQTT.
  factory ElectricData.placeholder() {
    final now = DateTime.now();
    return ElectricData(
      voltage: 220.0,
      current: 0,
      power: 0,
      energy: 0,
      alarm: 0,
      hour: now.hour,
      minute: now.minute,
    );
  }
}
