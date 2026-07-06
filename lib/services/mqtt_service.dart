import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttMessageWrapper {
  final String topic;
  final String message;

  MqttMessageWrapper({required this.topic, required this.message});
}

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  StreamController<MqttMessageWrapper>? _messageStreamController;
  StreamSubscription? _updatesSubscription;
  bool _isConnected = false;

  static const String dataTopic = 'electric';
  static const String relayTopic = 'relay';

  static const String _host =
      'a8e2eca8b3a54e48a698499b8d22c91d.s1.eu.hivemq.cloud';
  static const int _port = 8883;
  static const String _username = 'LongNe';
  static const String _password = 'Abc@1234';

  Stream<MqttMessageWrapper>? get messageStream =>
      _messageStreamController?.stream;
  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    try {
      final clientId = 'ev_charging_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient(_host, clientId);
      _client!.port = _port;
      _client!.secure = true;
      _client!.keepAlivePeriod = 60;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.logging(on: false);
      _client!.setProtocolV311();

      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .authenticateAs(_username, _password);

      _client!.connectionMessage = connMess;

      _messageStreamController =
          StreamController<MqttMessageWrapper>.broadcast();

      await _client!.connect().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _client?.disconnect();
          throw TimeoutException('Kết nối MQTT quá thời gian chờ');
        },
      );
      _isConnected =
          _client!.connectionStatus?.state == MqttConnectionState.connected;

      if (_isConnected) {
        _setupMessageListener();
        await subscribe(dataTopic);
        await subscribe(relayTopic);
      }

      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  void _setupMessageListener() {
    _updatesSubscription?.cancel();
    _updatesSubscription = _client!.updates?.listen((
      List<MqttReceivedMessage<MqttMessage>> messages,
    ) {
      for (final message in messages) {
        if (message.payload is MqttPublishMessage) {
          final payload = MqttPublishPayload.bytesToStringAsString(
            (message.payload as MqttPublishMessage).payload.message,
          );
          _messageStreamController?.add(
            MqttMessageWrapper(topic: message.topic, message: payload),
          );
        }
      }
    });
  }

  void _onConnected() {
    _isConnected = true;
  }

  void _onDisconnected() {
    _isConnected = false;
  }

  void _onSubscribed(String topic) {}

  Future<void> disconnect() async {
    try {
      await _updatesSubscription?.cancel();
      _updatesSubscription = null;
      _client?.disconnect();
      _isConnected = false;
      await _messageStreamController?.close();
      _messageStreamController = null;
    } catch (_) {}
  }

  Future<bool> subscribe(String topic) async {
    if (!_isConnected) return false;
    try {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unsubscribe(String topic) async {
    if (!_isConnected) return false;
    try {
      _client!.unsubscribe(topic);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> publish(String topic, String message) async {
    if (!_isConnected) return false;
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      return true;
    } catch (_) {
      return false;
    }
  }
}
