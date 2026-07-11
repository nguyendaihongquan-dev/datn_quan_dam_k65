class ElectricData {
  final double voltage;
  final double current;
  final double power;
  final double energy;
  final double frequency;
  final double pf;
  final double temperature;
  final double humidity;
  final int relayCommand;
  final int relay;
  final int buzzer;
  final int temperatureAlarm;
  final int pzemValid;
  final int dhtValid;
  final int rtcValid;
  final int wifi;
  final int mqttConnected;
  final String date;
  final String time;

  const ElectricData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.energy,
    required this.frequency,
    required this.pf,
    required this.temperature,
    required this.humidity,
    required this.relayCommand,
    required this.relay,
    required this.buzzer,
    required this.temperatureAlarm,
    required this.pzemValid,
    required this.dhtValid,
    required this.rtcValid,
    required this.wifi,
    required this.mqttConnected,
    required this.date,
    required this.time,
  });

  factory ElectricData.fromJson(Map<String, dynamic> json) {
    final timeStr = json['time']?.toString() ?? '';
    final parsedTime = _parseTimeParts(timeStr);

    return ElectricData(
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0,
      current: (json['current'] as num?)?.toDouble() ?? 0,
      power: (json['power'] as num?)?.toDouble() ?? 0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0,
      frequency: (json['frequency'] as num?)?.toDouble() ?? 0,
      pf: (json['pf'] as num?)?.toDouble() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0,
      relayCommand: json['relay_command'] ?? 0,
      relay: json['relay'] ?? 0,
      buzzer: json['buzzer'] ?? 0,
      temperatureAlarm: json['temperature_alarm'] ?? json['alarm'] ?? 0,
      pzemValid: json['pzem_valid'] ?? 0,
      dhtValid: json['dht_valid'] ?? 0,
      rtcValid: json['rtc_valid'] ?? 0,
      wifi: json['wifi'] ?? 0,
      mqttConnected: json['mqtt'] ?? 0,
      date: json['date']?.toString() ?? '',
      time: timeStr.isNotEmpty
          ? timeStr
          : _formatTime(
              json['hour'] ?? parsedTime.$1,
              json['minute'] ?? parsedTime.$2,
              json['second'] ?? parsedTime.$3,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'voltage': voltage,
    'current': current,
    'power': power,
    'energy': energy,
    'frequency': frequency,
    'pf': pf,
    'temperature': temperature,
    'humidity': humidity,
    'relay_command': relayCommand,
    'relay': relay,
    'buzzer': buzzer,
    'temperature_alarm': temperatureAlarm,
    'pzem_valid': pzemValid,
    'dht_valid': dhtValid,
    'rtc_valid': rtcValid,
    'wifi': wifi,
    'mqtt': mqttConnected,
    'date': date,
    'time': time,
  };

  bool get isCharging => current > 0.1 || power > 0.05;
  bool get hasAlarm => temperatureAlarm != 0 || buzzer != 0;
  bool get relayOn => relay != 0;

  String get dateLabel => date.isNotEmpty ? date : '--/--/----';

  String get timeLabel {
    if (time.isNotEmpty) return time;
    return '--:--:--';
  }

  String get dateTimeLabel => '$dateLabel $timeLabel';

  int get hour => _parseTimeParts(time).$1;
  int get minute => _parseTimeParts(time).$2;

  String get statusLabel {
    if (hasAlarm) return 'Cảnh báo';
    if (isCharging) return 'Đang sạc';
    return 'Chờ kết nối';
  }

  factory ElectricData.placeholder() {
    final now = DateTime.now();
    return ElectricData(
      voltage: 220.0,
      current: 0,
      power: 0,
      energy: 0,
      frequency: 0,
      pf: 0,
      temperature: 0,
      humidity: 0,
      relayCommand: 0,
      relay: 0,
      buzzer: 0,
      temperatureAlarm: 0,
      pzemValid: 0,
      dhtValid: 0,
      rtcValid: 0,
      wifi: 0,
      mqttConnected: 0,
      date:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}',
      time:
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}',
    );
  }

  static (int, int, int) _parseTimeParts(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return (0, 0, 0);
    return (
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  static String _formatTime(int hour, int minute, int second) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}
