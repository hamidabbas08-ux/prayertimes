import 'package:flutter_test/flutter_test.dart';
import 'package:prayertimes/main.dart';

void main() {
  test('Prayer Times app can be created', () {
    const app = PrayerTimesApp();

    expect(app, isA<PrayerTimesApp>());
  });
}
