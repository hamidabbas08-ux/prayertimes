import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationSchedule {
  const PrayerNotificationSchedule({
    required this.id,
    required this.englishName,
    required this.arabicName,
    required this.dateTime,
  });

  final int id;
  final String englishName;
  final String arabicName;
  final DateTime dateTime;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'prayer_alerts';
  static const String _channelName = 'Prayer Alerts';
  static const String _channelDescription =
      'Prayer time notifications and Azan alerts';

  static const int _firstPrayerNotificationId = 3000;
  static const int _maximumPrayerNotifications = 35;

  Future<void> initialize() async {
    await _initializeTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {},
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initializeTimeZone() async {
    tz.initializeTimeZones();

    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> requestNotificationPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final granted = await androidPlugin?.requestNotificationsPermission();

    return granted ?? true;
  }

  Future<bool> requestExactAlarmPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final granted = await androidPlugin?.requestExactAlarmsPermission();

    return granted ?? true;
  }

  Future<void> cancelPrayerNotifications() async {
    for (var index = 0; index < _maximumPrayerNotifications; index++) {
      await _plugin.cancel(id: _firstPrayerNotificationId + index);
    }
  }

  Future<int> schedulePrayerNotifications(
    List<PrayerNotificationSchedule> schedules,
  ) async {
    await cancelPrayerNotifications();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledCount = 0;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'Prayer time alert',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    for (final schedule in schedules) {
      final scheduledDate = tz.TZDateTime.from(schedule.dateTime, tz.local);

      if (!scheduledDate.isAfter(now)) {
        continue;
      }

      await _plugin.zonedSchedule(
        id: schedule.id,
        title: '${schedule.englishName} Prayer • ${schedule.arabicName}',
        body: 'It is time for ${schedule.englishName} prayer.',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'prayer_${schedule.englishName.toLowerCase()}',
      );

      scheduledCount++;
    }

    return scheduledCount;
  }

  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'Prayer Times test notification',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 1001,
      title: 'Prayer Times',
      body: 'Test notification is working successfully.',
      notificationDetails: notificationDetails,
      payload: 'test_notification',
    );
  }
}
