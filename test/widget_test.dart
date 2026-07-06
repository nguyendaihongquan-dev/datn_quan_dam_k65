import 'package:flutter_test/flutter_test.dart';
import 'package:ev_charging_station/main.dart';

void main() {
  testWidgets('App renders loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EvChargingApp());
    expect(find.text('EV Charging'), findsNothing);
  });
}
