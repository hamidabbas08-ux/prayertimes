import 'package:flutter_test/flutter_test.dart';
import 'package:prayertimes/main.dart';

void main() {
  testWidgets('Prayer Times home screen loads', (tester) async {
    await tester.pumpWidget(const PrayerTimesApp());

    expect(find.text('Prayer Times'), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
  });
}
