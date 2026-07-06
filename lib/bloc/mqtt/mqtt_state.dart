import 'package:equatable/equatable.dart';

abstract class MqttState extends Equatable {
  const MqttState();

  @override
  List<Object?> get props => [];
}

class MqttInitial extends MqttState {}

class MqttConnecting extends MqttState {}

class MqttConnected extends MqttState {}

class MqttDisconnected extends MqttState {}

class MqttError extends MqttState {
  final String message;

  const MqttError(this.message);

  @override
  List<Object?> get props => [message];
}

class MqttMessageReceived extends MqttState {
  final String topic;
  final String message;
  final int sequence;

  const MqttMessageReceived({
    required this.topic,
    required this.message,
    required this.sequence,
  });

  @override
  List<Object?> get props => [topic, message, sequence];
}
