import 'package:flutter_test/flutter_test.dart';
import 'package:prayertimes/main.dart';

void main() {
  testWidgets('Prayer Times app opens successfully', (tester) async {
    await tester.pumpWidget(const PrayerTimesApp());

    expect(find.text('Prayer Times'), findsOneWidget);
    expect(find.text('Next Prayer'), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Dhuhr'), findsOneWidget);
    expect(find.text('Asr'), findsOneWidget);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
  });
}
