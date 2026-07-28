import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:prayertimes/screens/duas_screen.dart';
import 'package:prayertimes/screens/more_screen.dart';
import 'package:prayertimes/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const PrayerTimesApp());
}

class PrayerTimesApp extends StatelessWidget {
  const PrayerTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prayer Times',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F7F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075B3A),
          primary: const Color(0xFF075B3A),
          secondary: const Color(0xFFD5A63A),
          surface: const Color(0xFFFFFDF8),
        ),
      ),
      home: const PrayerHomeScreen(),
    );
  }
}

class PrayerHomeScreen extends StatefulWidget {
  const PrayerHomeScreen({super.key});

  @override
  State<PrayerHomeScreen> createState() => _PrayerHomeScreenState();
}

class _PrayerHomeScreenState extends State<PrayerHomeScreen>
    with WidgetsBindingObserver {
  int selectedIndex = 0;

  String locationName = 'Finding your location...';
  String coordinatesText = '';
  String? locationError;
  bool isLoadingLocation = false;
  bool isConfiguringPrayerAlerts = false;
  bool hasLoadedCurrentLocation = false;
  bool prayerPreferencesLoaded = false;
  String selectedTimeFormat = '12-hour';
  String selectedAsrMethod = 'Shafi';
  String selectedCalculationMethod = 'Dubai';
  int hijriAdjustmentDays = 0;

  final SharedPreferencesAsync prayerPreferences = SharedPreferencesAsync();

  final Map<String, bool> enabledPrayerAlerts = {
    'Fajr': true,
    'Dhuhr': true,
    'Asr': true,
    'Maghrib': true,
    'Isha': true,
  };

  double latitude = 24.1969;
  double longitude = 55.7625;

  Timer? countdownTimer;
  DateTime currentTime = DateTime.now();
  DateTime timetableMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<PrayerItem> prayers = [];
  PrayerItem? nextPrayer;
  Duration nextPrayerRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadPrayerAlertPreferences();
    _loadTimeFormatPreference();
    _loadAsrMethodPreference();
    _loadCalculationMethodPreference();
    _loadHijriAdjustmentPreference();
    _calculatePrayerTimes();

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        currentTime = DateTime.now();
        _updateNextPrayer();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!hasLoadedCurrentLocation) return;

    Future<void>.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted) return;

      await _configurePrayerAlerts(
        showSuccessMessage: false,
        requestPermissions: false,
      );
    });
  }

  Future<void> _loadCurrentLocation() async {
    if (isLoadingLocation) return;

    setState(() {
      isLoadingLocation = true;
      locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Please turn on Location/GPS and tap refresh.');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
          'Please allow it from App Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      String detectedLocation = 'Current Location';

      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          final city = _firstAvailable([
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ]);

          final country = place.country?.trim() ?? '';

          if (city.isNotEmpty && country.isNotEmpty) {
            detectedLocation = '$city, $country';
          } else if (city.isNotEmpty) {
            detectedLocation = city;
          } else if (country.isNotEmpty) {
            detectedLocation = country;
          }
        }
      } catch (_) {
        detectedLocation = 'Current Location';
      }

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        locationName = detectedLocation;
        coordinatesText = _formatCoordinates(
          position.latitude,
          position.longitude,
        );
        locationError = null;
        isLoadingLocation = false;
        hasLoadedCurrentLocation = true;

        _calculatePrayerTimes();
      });

      await _configurePrayerAlerts(
        showSuccessMessage: false,
        requestPermissions: true,
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');

      setState(() {
        isLoadingLocation = false;
        locationError = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadCurrentLocation,
          ),
        ),
      );
    }
  }

  void _calculatePrayerTimes() {
    final coordinates = Coordinates(latitude, longitude);

    final parameters = _buildCalculationParameters();

    final now = DateTime.now();

    final calculated = PrayerTimes(
      coordinates: coordinates,
      date: now,
      calculationParameters: parameters,
      precision: true,
    );

    final tomorrow = now.add(const Duration(days: 1));

    final tomorrowCalculated = PrayerTimes(
      coordinates: coordinates,
      date: tomorrow,
      calculationParameters: parameters,
      precision: true,
    );

    prayers = [
      PrayerItem(
        englishName: 'Fajr',
        arabicName: 'الفجر',
        dateTime: calculated.fajr.toLocal(),
        icon: Icons.wb_twilight_rounded,
      ),
      PrayerItem(
        englishName: 'Dhuhr',
        arabicName: 'الظهر',
        dateTime: calculated.dhuhr.toLocal(),
        icon: Icons.wb_sunny_outlined,
      ),
      PrayerItem(
        englishName: 'Asr',
        arabicName: 'العصر',
        dateTime: calculated.asr.toLocal(),
        icon: Icons.sunny_snowing,
      ),
      PrayerItem(
        englishName: 'Maghrib',
        arabicName: 'المغرب',
        dateTime: calculated.maghrib.toLocal(),
        icon: Icons.wb_twilight,
      ),
      PrayerItem(
        englishName: 'Isha',
        arabicName: 'العشاء',
        dateTime: calculated.isha.toLocal(),
        icon: Icons.dark_mode_outlined,
      ),
    ];

    final tomorrowFajr = PrayerItem(
      englishName: 'Fajr',
      arabicName: 'الفجر',
      dateTime: tomorrowCalculated.fajr.toLocal(),
      icon: Icons.wb_twilight_rounded,
      isTomorrow: true,
    );

    _updateNextPrayer(tomorrowFajr: tomorrowFajr);
  }

  void _updateNextPrayer({PrayerItem? tomorrowFajr}) {
    if (prayers.isEmpty) return;

    final now = DateTime.now();
    PrayerItem? detectedNext;

    for (final prayer in prayers) {
      if (prayer.dateTime.isAfter(now)) {
        detectedNext = prayer;
        break;
      }
    }

    if (detectedNext == null) {
      if (tomorrowFajr != null) {
        detectedNext = tomorrowFajr;
      } else {
        final coordinates = Coordinates(latitude, longitude);

        final parameters = _buildCalculationParameters();

        final tomorrowTimes = PrayerTimes(
          coordinates: coordinates,
          date: now.add(const Duration(days: 1)),
          calculationParameters: parameters,
          precision: true,
        );

        detectedNext = PrayerItem(
          englishName: 'Fajr',
          arabicName: 'الفجر',
          dateTime: tomorrowTimes.fajr.toLocal(),
          icon: Icons.wb_twilight_rounded,
          isTomorrow: true,
        );
      }
    }

    nextPrayer = detectedNext;

    final difference = detectedNext.dateTime.difference(now);

    nextPrayerRemaining = difference.isNegative ? Duration.zero : difference;
  }

  String _firstAvailable(List<String?> values) {
    for (final value in values) {
      final cleaned = value?.trim() ?? '';

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return '';
  }

  String _formatCoordinates(double latitude, double longitude) {
    final latitudeDirection = latitude >= 0 ? 'N' : 'S';
    final longitudeDirection = longitude >= 0 ? 'E' : 'W';

    return '${latitude.abs().toStringAsFixed(4)}° $latitudeDirection, '
        '${longitude.abs().toStringAsFixed(4)}° $longitudeDirection';
  }

  Future<void> _loadHijriAdjustmentPreference() async {
    final storedAdjustment = await prayerPreferences.getInt(
      'hijri_adjustment_days',
    );

    if (!mounted) return;

    setState(() {
      hijriAdjustmentDays = storedAdjustment ?? 0;
    });
  }

  Future<void> _changeHijriAdjustment(int days) async {
    if (hijriAdjustmentDays == days) return;

    setState(() {
      hijriAdjustmentDays = days;
    });

    await prayerPreferences.setInt('hijri_adjustment_days', days);

    if (!mounted) return;

    final message = switch (days) {
      0 => 'Hijri date adjustment removed.',
      1 => 'Hijri date adjusted by +1 day.',
      -1 => 'Hijri date adjusted by -1 day.',
      _ => 'Hijri date adjusted by ${days > 0 ? '+' : ''}$days days.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  CalculationParameters _buildCalculationParameters() {
    late final CalculationParameters parameters;

    switch (selectedCalculationMethod) {
      case 'Muslim World League':
        parameters = CalculationMethodParameters.muslimWorldLeague();
        break;
      case 'Karachi':
        parameters = CalculationMethodParameters.karachi();
        break;
      case 'Umm al-Qura':
        parameters = CalculationMethodParameters.ummAlQura();
        break;
      case 'Dubai':
      default:
        parameters = CalculationMethodParameters.dubai();
        break;
    }

    parameters.madhab = selectedAsrMethod == 'Hanafi'
        ? Madhab.hanafi
        : Madhab.shafi;

    return parameters;
  }

  Future<void> _loadCalculationMethodPreference() async {
    final storedMethod = await prayerPreferences.getString(
      'calculation_method',
    );

    if (!mounted) return;

    setState(() {
      selectedCalculationMethod = storedMethod ?? 'Dubai';
      _calculatePrayerTimes();
    });
  }

  Future<void> _changeCalculationMethod(String method) async {
    if (selectedCalculationMethod == method) return;

    setState(() {
      selectedCalculationMethod = method;
      _calculatePrayerTimes();
    });

    await prayerPreferences.setString('calculation_method', method);

    if (!mounted) return;

    await _configurePrayerAlerts(
      showSuccessMessage: false,
      requestPermissions: false,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calculation method changed to $method.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadAsrMethodPreference() async {
    final storedMethod = await prayerPreferences.getString('asr_method');

    if (!mounted) return;

    setState(() {
      selectedAsrMethod = storedMethod ?? 'Shafi';
      _calculatePrayerTimes();
    });
  }

  Future<void> _changeAsrMethod(String method) async {
    if (selectedAsrMethod == method) return;

    setState(() {
      selectedAsrMethod = method;
      _calculatePrayerTimes();
    });

    await prayerPreferences.setString('asr_method', method);

    if (!mounted) return;

    await _configurePrayerAlerts(
      showSuccessMessage: false,
      requestPermissions: false,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Asr calculation changed to $method.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadTimeFormatPreference() async {
    final storedFormat = await prayerPreferences.getString('time_format');

    if (!mounted) return;

    setState(() {
      selectedTimeFormat = storedFormat ?? '12-hour';
    });
  }

  Future<void> _changeTimeFormat(String format) async {
    if (selectedTimeFormat == format) return;

    setState(() {
      selectedTimeFormat = format;
    });

    await prayerPreferences.setString('time_format', format);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Time format changed to $format.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatPrayerTime(DateTime time) {
    final pattern = selectedTimeFormat == '24-hour' ? 'HH:mm' : 'hh:mm a';

    return DateFormat(pattern).format(time);
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  bool _isSamePrayer(PrayerItem prayer) {
    final next = nextPrayer;

    if (next == null || next.isTomorrow) return false;

    return prayer.englishName == next.englishName &&
        prayer.dateTime == next.dateTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildSelectedPage()),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSelectedPage() {
    switch (selectedIndex) {
      case 1:
        return _buildQiblaScreen();
      case 2:
        return _buildTimetableScreen();
      case 3:
        return const DuasScreen();
      case 4:
        return MoreScreen(
          locationName: locationName,
          coordinatesText: coordinatesText,
          enabledPrayerCount: enabledPrayerAlerts.values
              .where((enabled) => enabled)
              .length,
          isRefreshingLocation: isLoadingLocation,
          isSchedulingAlerts: isConfiguringPrayerAlerts,
          timeFormat: selectedTimeFormat,
          asrMethod: selectedAsrMethod,
          calculationMethod: selectedCalculationMethod,
          hijriAdjustmentDays: hijriAdjustmentDays,
          onTimeFormatChanged: _changeTimeFormat,
          onAsrMethodChanged: _changeAsrMethod,
          onCalculationMethodChanged: _changeCalculationMethod,
          onHijriAdjustmentChanged: _changeHijriAdjustment,
          onRefreshLocation: _loadCurrentLocation,
          onRefreshAzanSchedule: () async {
            await _configurePrayerAlerts(
              showSuccessMessage: true,
              requestPermissions: true,
            );
          },
        );
      case 0:
      default:
        return _buildHomeScreen();
    }
  }

  Widget _buildHomeScreen() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                _buildLocationCard(),
                const SizedBox(height: 12),
                _buildDateCard(),
                const SizedBox(height: 12),
                _buildNextPrayerCard(),
                const SizedBox(height: 14),
                _buildPrayerList(),
                const SizedBox(height: 18),
                _buildDailyMessage(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimetableScreen() {
    final monthlyRows = _buildMonthlyPrayerRows();
    final currentMonth = DateFormat('MMMM yyyy').format(timetableMonth);

    return Column(
      children: [
        _buildSimplePageHeader('Prayer Timetable'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              children: [
                _buildTimetableLocationCard(),
                const SizedBox(height: 14),
                _buildMonthSelector(currentMonth),
                const SizedBox(height: 14),
                _buildTimetableTable(monthlyRows),
                const SizedBox(height: 14),
                _buildTimetableNote(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<MonthlyPrayerRow> _buildMonthlyPrayerRows() {
    final rows = <MonthlyPrayerRow>[];
    final coordinates = Coordinates(latitude, longitude);

    final parameters = _buildCalculationParameters();

    final numberOfDays = DateTime(
      timetableMonth.year,
      timetableMonth.month + 1,
      0,
    ).day;

    for (var day = 1; day <= numberOfDays; day++) {
      final date = DateTime(timetableMonth.year, timetableMonth.month, day);

      final calculated = PrayerTimes(
        coordinates: coordinates,
        date: date,
        calculationParameters: parameters,
        precision: true,
      );

      rows.add(
        MonthlyPrayerRow(
          date: date,
          fajr: calculated.fajr.toLocal(),
          dhuhr: calculated.dhuhr.toLocal(),
          asr: calculated.asr.toLocal(),
          maghrib: calculated.maghrib.toLocal(),
          isha: calculated.isha.toLocal(),
        ),
      );
    }

    return rows;
  }

  Widget _buildTimetableLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _whiteCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF08734A),
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF223029),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  coordinatesText,
                  style: const TextStyle(
                    color: Color(0xFF747D78),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh location and timetable',
            onPressed: _loadCurrentLocation,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF08734A)),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(String currentMonth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: _whiteCardDecoration(),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () {
              setState(() {
                timetableMonth = DateTime(
                  timetableMonth.year,
                  timetableMonth.month - 1,
                );
              });
            },
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF08734A),
              size: 30,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  currentMonth,
                  style: const TextStyle(
                    color: Color(0xFF075B3A),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Monthly prayer times',
                  style: TextStyle(color: Color(0xFF7A837E), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () {
              setState(() {
                timetableMonth = DateTime(
                  timetableMonth.year,
                  timetableMonth.month + 1,
                );
              });
            },
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF08734A),
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableTable(List<MonthlyPrayerRow> rows) {
    return Container(
      width: double.infinity,
      decoration: _whiteCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF087247),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
            child: const Row(
              children: [
                Expanded(flex: 13, child: _TimetableHeading('Date')),
                Expanded(flex: 17, child: _TimetableHeading('Fajr')),
                Expanded(flex: 17, child: _TimetableHeading('Dhuhr')),
                Expanded(flex: 17, child: _TimetableHeading('Asr')),
                Expanded(flex: 18, child: _TimetableHeading('Maghrib')),
                Expanded(flex: 18, child: _TimetableHeading('Isha')),
              ],
            ),
          ),
          ...List.generate(rows.length, (index) {
            final row = rows[index];
            final today = DateTime.now();

            final isToday =
                row.date.year == today.year &&
                row.date.month == today.month &&
                row.date.day == today.day;

            return Container(
              color: isToday
                  ? const Color(0xFFE2F2E9)
                  : index.isEven
                  ? const Color(0xFFFFFDF9)
                  : const Color(0xFFF7F8F5),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    flex: 13,
                    child: Text(
                      row.date.day.toString().padLeft(2, '0'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isToday
                            ? const Color(0xFF08734A)
                            : const Color(0xFF313C37),
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(flex: 17, child: _timetableTime(row.fajr, isToday)),
                  Expanded(flex: 17, child: _timetableTime(row.dhuhr, isToday)),
                  Expanded(flex: 17, child: _timetableTime(row.asr, isToday)),
                  Expanded(
                    flex: 18,
                    child: _timetableTime(row.maghrib, isToday),
                  ),
                  Expanded(flex: 18, child: _timetableTime(row.isha, isToday)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _timetableTime(DateTime time, bool isToday) {
    return Text(
      DateFormat(
        selectedTimeFormat == '24-hour' ? 'HH:mm' : 'hh:mm',
      ).format(time),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: isToday ? const Color(0xFF08734A) : const Color(0xFF35413B),
        fontSize: 11,
        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
      ),
    );
  }

  Widget _buildTimetableNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE4D7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF08734A), size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Prayer times are calculated from your current location '
              'using the Dubai calculation method and Shafi Madhab.',
              style: TextStyle(
                color: Color(0xFF405149),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePageHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          _roundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              setState(() {
                selectedIndex = 0;
              });
            },
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF075B3A),
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  double _calculateQiblaBearing() {
    const kaabaLatitude = 21.4225;
    const kaabaLongitude = 39.8262;

    final userLatitudeRadians = latitude * math.pi / 180;
    final userLongitudeRadians = longitude * math.pi / 180;
    final kaabaLatitudeRadians = kaabaLatitude * math.pi / 180;
    final kaabaLongitudeRadians = kaabaLongitude * math.pi / 180;

    final longitudeDifference = kaabaLongitudeRadians - userLongitudeRadians;

    final y = math.sin(longitudeDifference) * math.cos(kaabaLatitudeRadians);

    final x =
        math.cos(userLatitudeRadians) * math.sin(kaabaLatitudeRadians) -
        math.sin(userLatitudeRadians) *
            math.cos(kaabaLatitudeRadians) *
            math.cos(longitudeDifference);

    final bearing = math.atan2(y, x) * 180 / math.pi;

    return (bearing + 360) % 360;
  }

  String _cardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

    final index = ((degrees + 22.5) ~/ 45) % 8;
    return directions[index];
  }

  double _smallestAngleDifference(double first, double second) {
    final difference = (first - second).abs() % 360;
    return difference > 180 ? 360 - difference : difference;
  }

  Widget _buildQiblaScreen() {
    final qiblaBearing = _calculateQiblaBearing();
    final compassEvents = FlutterCompass.events;

    return Column(
      children: [
        _buildSimplePageHeader('Qibla Direction'),
        Expanded(
          child: StreamBuilder<CompassEvent>(
            stream: compassEvents,
            builder: (context, snapshot) {
              final heading = snapshot.data?.heading;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  children: [
                    _buildQiblaLocationCard(qiblaBearing),
                    const SizedBox(height: 18),
                    if (heading == null)
                      _buildCompassUnavailableCard()
                    else
                      _buildLiveCompass(
                        heading: heading,
                        qiblaBearing: qiblaBearing,
                      ),
                    const SizedBox(height: 18),
                    _buildQiblaInstructions(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQiblaLocationCard(double qiblaBearing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _whiteCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3ED),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF08734A),
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF223029),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qibla bearing ${qiblaBearing.toStringAsFixed(1)}° '
                  '${_cardinalDirection(qiblaBearing)}',
                  style: const TextStyle(
                    color: Color(0xFF737D77),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _loadCurrentLocation,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF08734A)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCompass({
    required double heading,
    required double qiblaBearing,
  }) {
    final normalizedHeading = (heading + 360) % 360;
    final rotationDegrees = (qiblaBearing - normalizedHeading + 360) % 360;
    final angleDifference = _smallestAngleDifference(
      normalizedHeading,
      qiblaBearing,
    );

    final isFacingQibla = angleDifference <= 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF087247), Color(0xFF03462F)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33004B31),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isFacingQibla ? 'Facing Qibla' : 'Turn towards the arrow',
            style: TextStyle(
              color: isFacingQibla ? const Color(0xFFF5D77C) : Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isFacingQibla
                ? 'You are aligned with the Kaaba'
                : '${angleDifference.toStringAsFixed(0)}° away from Qibla',
            style: const TextStyle(color: Color(0xFFD8EAE0), fontSize: 13),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 285,
            height: 285,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 275,
                  height: 275,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x14FFFFFF),
                    border: Border.all(
                      color: isFacingQibla
                          ? const Color(0xFFF5D77C)
                          : const Color(0x66FFFFFF),
                      width: isFacingQibla ? 3 : 2,
                    ),
                  ),
                ),
                const Positioned(
                  top: 13,
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: Color(0xFFF5D77C),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Positioned(
                  right: 17,
                  child: Text(
                    'E',
                    style: TextStyle(
                      color: Color(0xFFD8EAE0),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 13,
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: Color(0xFFD8EAE0),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Positioned(
                  left: 17,
                  child: Text(
                    'W',
                    style: TextStyle(
                      color: Color(0xFFD8EAE0),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: rotationDegrees * math.pi / 180,
                  child: SizedBox(
                    width: 210,
                    height: 210,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 4,
                          child: Column(
                            children: [
                              Icon(
                                Icons.navigation_rounded,
                                color: isFacingQibla
                                    ? const Color(0xFFF5D77C)
                                    : Colors.white,
                                size: 66,
                              ),
                              const SizedBox(height: 2),
                              const Icon(
                                Icons.mosque_rounded,
                                color: Color(0xFFF5D77C),
                                size: 32,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFFDF8),
                    border: Border.all(
                      color: const Color(0xFFF5D77C),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(
                    Icons.mosque_outlined,
                    color: Color(0xFF087247),
                    size: 43,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _qiblaReadingTile(
                  label: 'Phone heading',
                  value:
                      '${normalizedHeading.toStringAsFixed(0)}° '
                      '${_cardinalDirection(normalizedHeading)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _qiblaReadingTile(
                  label: 'Qibla direction',
                  value:
                      '${qiblaBearing.toStringAsFixed(0)}° '
                      '${_cardinalDirection(qiblaBearing)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qiblaReadingTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x28FFFFFF)),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCFE3D8), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompassUnavailableCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _whiteCardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.explore_off_outlined, color: Color(0xFF9A6A37), size: 56),
          SizedBox(height: 15),
          Text(
            'Compass sensor unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF27342E),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Move the phone in a figure-eight motion. If the compass '
            'still does not appear, this device may not include a '
            'magnetic compass sensor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF707A74),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQiblaInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE4D7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF08734A), size: 25),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Keep the phone flat and away from metal objects, magnets '
              'and electrical equipment. Turn slowly until the arrow '
              'points straight ahead and “Facing Qibla” appears.',
              style: TextStyle(
                color: Color(0xFF405149),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPrayerAlertPreferences() async {
    final loadedValues = <String, bool>{};

    for (final prayerName in enabledPrayerAlerts.keys) {
      final storedValue = await prayerPreferences.getBool(
        'prayer_alert_${prayerName.toLowerCase()}',
      );

      loadedValues[prayerName] = storedValue ?? true;
    }

    if (!mounted) return;

    setState(() {
      enabledPrayerAlerts.addAll(loadedValues);
      prayerPreferencesLoaded = true;
    });
  }

  Future<void> _togglePrayerAlert(String prayerName) async {
    final currentlyEnabled = enabledPrayerAlerts[prayerName] ?? true;
    final newValue = !currentlyEnabled;

    setState(() {
      enabledPrayerAlerts[prayerName] = newValue;
    });

    await prayerPreferences.setBool(
      'prayer_alert_${prayerName.toLowerCase()}',
      newValue,
    );

    if (!mounted) return;

    await _configurePrayerAlerts(
      showSuccessMessage: false,
      requestPermissions: newValue,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? '$prayerName Azan alert turned on.'
              : '$prayerName Azan alert turned off.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<PrayerNotificationSchedule> _buildThirtyDayPrayerSchedules() {
    final schedules = <PrayerNotificationSchedule>[];
    final coordinates = Coordinates(latitude, longitude);

    final parameters = _buildCalculationParameters();

    final startingDate = DateTime.now();

    for (var dayOffset = 0; dayOffset < 30; dayOffset++) {
      final date = DateTime(
        startingDate.year,
        startingDate.month,
        startingDate.day + dayOffset,
      );

      final calculated = PrayerTimes(
        coordinates: coordinates,
        date: date,
        calculationParameters: parameters,
        precision: true,
      );

      final dailyPrayers = [
        (
          englishName: 'Fajr',
          arabicName: 'الفجر',
          dateTime: calculated.fajr.toLocal(),
        ),
        (
          englishName: 'Dhuhr',
          arabicName: 'الظهر',
          dateTime: calculated.dhuhr.toLocal(),
        ),
        (
          englishName: 'Asr',
          arabicName: 'العصر',
          dateTime: calculated.asr.toLocal(),
        ),
        (
          englishName: 'Maghrib',
          arabicName: 'المغرب',
          dateTime: calculated.maghrib.toLocal(),
        ),
        (
          englishName: 'Isha',
          arabicName: 'العشاء',
          dateTime: calculated.isha.toLocal(),
        ),
      ];

      for (
        var prayerIndex = 0;
        prayerIndex < dailyPrayers.length;
        prayerIndex++
      ) {
        final prayer = dailyPrayers[prayerIndex];

        final isEnabled = enabledPrayerAlerts[prayer.englishName] ?? true;

        if (!isEnabled) {
          continue;
        }

        schedules.add(
          PrayerNotificationSchedule(
            id: 3000 + (dayOffset * 5) + prayerIndex,
            englishName: prayer.englishName,
            arabicName: prayer.arabicName,
            dateTime: prayer.dateTime,
          ),
        );
      }
    }

    return schedules;
  }

  Future<void> _configurePrayerAlerts({
    required bool showSuccessMessage,
    required bool requestPermissions,
  }) async {
    if (isConfiguringPrayerAlerts) return;
    if (!prayerPreferencesLoaded) return;

    isConfiguringPrayerAlerts = true;

    try {
      var notificationPermission = true;

      if (requestPermissions) {
        notificationPermission = await NotificationService.instance
            .requestNotificationPermission();
      }

      if (!mounted) return;

      if (!notificationPermission) {
        if (showSuccessMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission is required for Azan alerts.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      var exactAlarmAllowed = await NotificationService.instance
          .canScheduleExactAlarms();

      if (!exactAlarmAllowed && requestPermissions) {
        await NotificationService.instance.requestExactAlarmPermission();

        exactAlarmAllowed = await NotificationService.instance
            .canScheduleExactAlarms();
      }

      if (!mounted) return;

      if (!exactAlarmAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enable Alarms and reminders, then return to the app.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      final schedules = _buildThirtyDayPrayerSchedules();

      final scheduledCount = await NotificationService.instance
          .schedulePrayerNotifications(schedules);

      if (!mounted) return;

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$scheduledCount Azan alerts scheduled for the next 30 days.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not schedule Azan alerts: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      isConfiguringPrayerAlerts = false;
    }
  }

  Future<void> _showTestNotification() async {
    await _configurePrayerAlerts(
      showSuccessMessage: true,
      requestPermissions: true,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          _roundIconButton(icon: Icons.menu_rounded, onTap: () {}),
          const Expanded(
            child: Text(
              'Prayer Times',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF075B3A),
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          _roundIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: _showTestNotification,
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFEAF3EE),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF075B3A)),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _whiteCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF08734A),
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoadingLocation ? 'Finding your location...' : locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E2924),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locationError ?? coordinatesText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: locationError == null
                        ? const Color(0xFF7B847F)
                        : const Color(0xFFB04444),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (isLoadingLocation)
            const SizedBox(
              width: 42,
              height: 42,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF075B3A),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh location and prayer times',
              onPressed: _loadCurrentLocation,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF075B3A)),
            ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    final now = currentTime;
    final adjustedHijriSource = now.add(Duration(days: hijriAdjustmentDays));
    final hijriDate = HijriCalendar.fromDate(adjustedHijriSource);
    final formattedHijriDate =
        '${hijriDate.hDay} ${hijriDate.getLongMonthName()} '
        '${hijriDate.hYear} AH';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: _whiteCardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedHijriDate,
                  style: const TextStyle(
                    color: Color(0xFF26332D),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('EEEE').format(now),
                  style: const TextStyle(
                    color: Color(0xFF7A837E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.calendar_month_outlined, color: Color(0xFF0A754B)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('dd MMMM yyyy').format(now),
                style: const TextStyle(
                  color: Color(0xFF26332D),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Gregorian',
                style: TextStyle(color: Color(0xFF7A837E), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    final prayer = nextPrayer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF087247), Color(0xFF03472F)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33004B31),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -22,
            child: Icon(
              Icons.mosque_rounded,
              size: 128,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Next Prayer',
                    style: TextStyle(
                      color: Color(0xFFD8E9DF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFE6C46B),
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      prayer?.englishName ?? 'Calculating...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (prayer != null) ...[
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '/ ${prayer.arabicName}',
                        textDirection: ui.TextDirection.rtl,
                        style: const TextStyle(
                          color: Color(0xFFE8C76F),
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'In ${_formatCountdown(nextPrayerRemaining)}',
                style: const TextStyle(
                  color: Color(0xFFF4D675),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                prayer == null
                    ? 'Calculating prayer time'
                    : 'Prayer time ${_formatPrayerTime(prayer.dateTime)}'
                          '${prayer.isTomorrow ? ' tomorrow' : ''}',
                style: const TextStyle(color: Color(0xFFD7E8DE), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerList() {
    return Container(
      decoration: _whiteCardDecoration(),
      child: Column(
        children: List.generate(prayers.length, (index) {
          final prayer = prayers[index];

          return Column(
            children: [
              _PrayerRow(
                prayer: prayer,
                isNext: _isSamePrayer(prayer),
                formattedTime: _formatPrayerTime(prayer.dateTime),
                alertEnabled: enabledPrayerAlerts[prayer.englishName] ?? true,
                onAlertTap: () {
                  _togglePrayerAlert(prayer.englishName);
                },
              ),
              if (index != prayers.length - 1)
                const Divider(
                  height: 1,
                  indent: 17,
                  endIndent: 17,
                  color: Color(0xFFE9E7E0),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDailyMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE4D7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: Color(0xFF08734A), size: 30),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Reminder',
                  style: TextStyle(
                    color: Color(0xFF075B3A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Indeed, prayer has been decreed upon the believers '
                  'at specified times.',
                  style: TextStyle(
                    color: Color(0xFF405149),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    const items = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.explore_outlined),
        activeIcon: Icon(Icons.explore_rounded),
        label: 'Qibla',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_outlined),
        activeIcon: Icon(Icons.calendar_month_rounded),
        label: 'Timetable',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_outlined),
        activeIcon: Icon(Icons.menu_book_rounded),
        label: 'Duas',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.more_horiz_rounded),
        label: 'More',
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF9),
        boxShadow: [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFFFFDF9),
        selectedItemColor: const Color(0xFF08734A),
        unselectedItemColor: const Color(0xFF737B77),
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
        items: items,
      ),
    );
  }

  BoxDecoration _whiteCardDecoration() {
    return BoxDecoration(
      color: const Color(0xFFFFFDF9),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEAE7DF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}

class MonthlyPrayerRow {
  const MonthlyPrayerRow({
    required this.date,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final DateTime date;
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
}

class _TimetableHeading extends StatelessWidget {
  const _TimetableHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class PrayerItem {
  final String englishName;
  final String arabicName;
  final DateTime dateTime;
  final IconData icon;
  final bool isTomorrow;

  const PrayerItem({
    required this.englishName,
    required this.arabicName,
    required this.dateTime,
    required this.icon,
    this.isTomorrow = false,
  });
}

class _PrayerRow extends StatelessWidget {
  final PrayerItem prayer;
  final bool isNext;
  final String formattedTime;
  final bool alertEnabled;
  final VoidCallback onAlertTap;

  const _PrayerRow({
    required this.prayer,
    required this.isNext,
    required this.formattedTime,
    required this.alertEnabled,
    required this.onAlertTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: isNext
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: isNext
          ? BoxDecoration(
              color: const Color(0xFFEAF4EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF98C5AA)),
            )
          : null,
      child: Row(
        children: [
          Icon(
            prayer.icon,
            color: isNext ? const Color(0xFF08734A) : const Color(0xFF709086),
            size: 23,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Row(
              children: [
                Text(
                  prayer.englishName,
                  style: TextStyle(
                    color: const Color(0xFF25312B),
                    fontSize: 15,
                    fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '/ ${prayer.arabicName}',
                    textDirection: ui.TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isNext
                          ? const Color(0xFF08734A)
                          : const Color(0xFF6D7671),
                      fontSize: 15,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formattedTime,
            style: TextStyle(
              color: const Color(0xFF1F2A25),
              fontSize: 14,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          IconButton(
            tooltip: alertEnabled
                ? 'Turn off ${prayer.englishName} Azan'
                : 'Turn on ${prayer.englishName} Azan',
            onPressed: onAlertTap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(
              alertEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              color: alertEnabled
                  ? const Color(0xFF08734A)
                  : const Color(0xFF9A9F9C),
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}
