import 'package:equatable/equatable.dart';

abstract class MqttEvent extends Equatable {
  const MqttEvent();

  @override
  List<Object?> get props => [];
}

class MqttConnectEvent extends MqttEvent {
  const MqttConnectEvent();
}

class MqttDisconnectEvent extends MqttEvent {
  const MqttDisconnectEvent();
}

class MqttReconnectEvent extends MqttEvent {
  const MqttReconnectEvent();
}
