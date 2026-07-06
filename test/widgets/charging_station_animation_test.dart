import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ev_charging_station/widgets/charging_station_animation.dart';

void main() {
  testWidgets('renders idle labels when not charging', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChargingStationAnimation(isCharging: false)),
      ),
    );

    expect(find.text('Lưới điện'), findsOneWidget);
    expect(find.text('Trạm sạc'), findsOneWidget);
    expect(find.text('Pin xe'), findsOneWidget);
    expect(find.byIcon(Icons.battery_std), findsOneWidget);
  });

  testWidgets('switches to charging battery icon when isCharging is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChargingStationAnimation(isCharging: false)),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChargingStationAnimation(isCharging: true)),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.battery_charging_full), findsOneWidget);
  });

  testWidgets('returns to idle battery icon when charging stops', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChargingStationAnimation(isCharging: true)),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChargingStationAnimation(isCharging: false)),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.battery_std), findsOneWidget);
  });
}
