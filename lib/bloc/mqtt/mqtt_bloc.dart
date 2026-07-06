import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ev_charging_station/services/mqtt_service.dart';

import 'mqtt_event.dart';
import 'mqtt_state.dart';

class MqttBloc extends Bloc<MqttEvent, MqttState> {
  final MqttService _mqttService = MqttService();
  StreamSubscription? _messageSubscription;

  MqttBloc() : super(MqttInitial()) {
    on<MqttConnectEvent>(_onConnect);
    on<MqttDisconnectEvent>(_onDisconnect);
    on<_MqttMessageInternal>(_onMessage);
  }

  Future<void> _onConnect(
    MqttConnectEvent event,
    Emitter<MqttState> emit,
  ) async {
    try {
      emit(MqttConnecting());
      final connected = await _mqttService.connect();
      if (connected) {
        emit(MqttConnected());
        _setupMessageListener();
      } else {
        emit(const MqttError('Không thể kết nối tới broker MQTT.'));
      }
    } catch (e) {
      emit(MqttError(e.toString()));
    }
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = _mqttService.messageStream?.listen(
      (wrapper) => add(_MqttMessageInternal(wrapper)),
    );
  }

  void _onMessage(_MqttMessageInternal event, Emitter<MqttState> emit) {
    emit(
      MqttMessageReceived(
        topic: event.wrapper.topic,
        message: event.wrapper.message,
      ),
    );
  }

  Future<void> _onDisconnect(
    MqttDisconnectEvent event,
    Emitter<MqttState> emit,
  ) async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _mqttService.disconnect();
    emit(MqttDisconnected());
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    await _mqttService.disconnect();
    return super.close();
  }
}

class _MqttMessageInternal extends MqttEvent {
  final MqttMessageWrapper wrapper;
  const _MqttMessageInternal(this.wrapper);

  @override
  List<Object?> get props => [wrapper];
}
