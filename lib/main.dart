import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_bloc.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_event.dart';
import 'package:ev_charging_station/bloc/relay/relay_bloc.dart';
import 'package:ev_charging_station/bloc/relay/relay_event.dart';
import 'package:ev_charging_station/screens/charging_home_screen.dart';
import 'package:ev_charging_station/services/firebase_service.dart';
import 'package:ev_charging_station/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(FirebaseService.initialize());
  runApp(const EvChargingApp());
}

class EvChargingApp extends StatelessWidget {
  const EvChargingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MqttBloc()..add(const MqttConnectEvent())),
        BlocProvider(create: (_) => RelayBloc()..add(const RelayInitEvent())),
      ],
      child: MaterialApp(
        title: 'EV Charging Station',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const ChargingHomeScreen(),
      ),
    );
  }
}
