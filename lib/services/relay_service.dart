import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ev_charging_station/config/app_config.dart';
import 'package:ev_charging_station/models/relay_state.dart';
import 'package:ev_charging_station/services/firebase_service.dart'
    as app_firebase;
import 'package:ev_charging_station/services/mqtt_service.dart';

class RelayService {
  RelayService({MqttService? mqttService})
    : _mqtt = mqttService ?? MqttService();

  final MqttService _mqtt;
  DatabaseReference? _relayRef;
  StreamSubscription<DatabaseEvent>? _subscription;

  DatabaseReference get _ref {
    _relayRef ??= FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: AppConfig.databaseUrl,
    ).ref(AppConfig.relayFirebasePath);
    return _relayRef!;
  }

  Stream<RelayStateModel> watchState() {
    return _ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        return RelayStateModel.fromMap(value);
      }
      return RelayStateModel.initial(
        isOn: AppConfig.relayDefaultState,
        source: 'default',
      );
    });
  }

  /// Khởi tạo node Firebase nếu chưa tồn tại.
  Future<RelayStateModel> ensureInitialized() async {
    if (!app_firebase.FirebaseService.isInitialized) {
      return RelayStateModel.initial(
        isOn: AppConfig.relayDefaultState,
        source: 'local',
      );
    }

    final snapshot = await _ref.get();
    if (!snapshot.exists) {
      final initial = RelayStateModel.initial(
        isOn: AppConfig.relayDefaultState,
        source: 'init',
      );
      await _ref.set({
        ...initial.toMap(),
        'defaultState': AppConfig.relayDefaultState,
      });
      return initial;
    }

    final map = snapshot.value as Map<dynamic, dynamic>;
    if (!map.containsKey('defaultState')) {
      await _ref.update({'defaultState': AppConfig.relayDefaultState});
    }
    return RelayStateModel.fromMap(map);
  }

  Future<void> setState(bool isOn, {required String source}) async {
    final model = RelayStateModel.initial(isOn: isOn, source: source);

    if (app_firebase.FirebaseService.isInitialized) {
      await _ref.update(model.toMap());
    }

    await _publishMqtt(isOn);
  }

  Future<bool> _publishMqtt(bool isOn) async {
    final payload = jsonEncode({'state': isOn ? 1 : 0});
    return _mqtt.publish(AppConfig.relayTopic, payload);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
