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

  static const String _fajrChannelId = 'fajr_azan_channel_v1';
  static const String _fajrChannelName = 'Fajr Azan';

  static const String _normalAzanChannelId = 'prayer_azan_channel_v1';
  static const String _normalAzanChannelName = 'Prayer Azan';

  static const int _firstPrayerNotificationId = 3000;
  static const int _maximumPrayerNotifications = 150;

  static const RawResourceAndroidNotificationSound _fajrSound =
      RawResourceAndroidNotificationSound('azan_fajr');

  static const RawResourceAndroidNotificationSound _normalAzanSound =
      RawResourceAndroidNotificationSound('azan_normal');

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

    await _createAzanChannels();
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

  Future<void> _createAzanChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    const fajrChannel = AndroidNotificationChannel(
      _fajrChannelId,
      _fajrChannelName,
      description: 'Fajr prayer notifications with Fajr Azan',
      importance: Importance.max,
      playSound: true,
      sound: _fajrSound,
      enableVibration: true,
    );

    const normalAzanChannel = AndroidNotificationChannel(
      _normalAzanChannelId,
      _normalAzanChannelName,
      description: 'Prayer notifications with Azan',
      importance: Importance.max,
      playSound: true,
      sound: _normalAzanSound,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(fajrChannel);
    await androidPlugin?.createNotificationChannel(normalAzanChannel);
  }

  Future<bool> requestNotificationPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final granted = await androidPlugin?.requestNotificationsPermission();

    return granted ?? true;
  }

  Future<bool> canScheduleExactAlarms() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final allowed = await androidPlugin?.canScheduleExactNotifications();

    return allowed ?? true;
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

    await _plugin.cancel(id: 2101);
  }

  Future<int> schedulePrayerNotifications(
    List<PrayerNotificationSchedule> schedules,
  ) async {
    await cancelPrayerNotifications();
    await _createAzanChannels();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledCount = 0;

    for (final schedule in schedules) {
      final scheduledDate = tz.TZDateTime.from(schedule.dateTime, tz.local);

      if (!scheduledDate.isAfter(now)) {
        continue;
      }

      final isFajr = schedule.englishName.toLowerCase() == 'fajr';

      final androidDetails = AndroidNotificationDetails(
        isFajr ? _fajrChannelId : _normalAzanChannelId,
        isFajr ? _fajrChannelName : _normalAzanChannelName,
        channelDescription: isFajr
            ? 'Fajr prayer notifications with Fajr Azan'
            : 'Prayer notifications with Azan',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: isFajr ? _fajrSound : _normalAzanSound,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ticker: '${schedule.englishName} prayer time',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

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
}
