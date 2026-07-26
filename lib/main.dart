import 'dart:async';
import 'dart:ui' as ui;

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:prayertimes/services/notification_service.dart';

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

class _PrayerHomeScreenState extends State<PrayerHomeScreen> {
  int selectedIndex = 0;

  String locationName = 'Finding your location...';
  String coordinatesText = '';
  String? locationError;
  bool isLoadingLocation = false;

  double latitude = 24.1969;
  double longitude = 55.7625;

  Timer? countdownTimer;
  DateTime currentTime = DateTime.now();

  List<PrayerItem> prayers = [];
  PrayerItem? nextPrayer;
  Duration nextPrayerRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();

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
    countdownTimer?.cancel();
    super.dispose();
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

        _calculatePrayerTimes();
      });
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

    final parameters = CalculationMethodParameters.dubai()
      ..madhab = Madhab.shafi;

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

        final parameters = CalculationMethodParameters.dubai()
          ..madhab = Madhab.shafi;

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

  String _formatPrayerTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
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
      body: SafeArea(
        child: Column(
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
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Future<void> _showTestNotification() async {
    final permissionGranted = await NotificationService.instance
        .requestNotificationPermission();

    if (!mounted) return;

    if (!permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification permission is required for prayer alerts.',
          ),
        ),
      );
      return;
    }

    await NotificationService.instance.showTestNotification();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent. Check the notification panel.'),
      ),
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
    final hijriDate = HijriCalendar.fromDate(now);
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

  const _PrayerRow({
    required this.prayer,
    required this.isNext,
    required this.formattedTime,
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
          const SizedBox(width: 9),
          const Icon(
            Icons.volume_up_outlined,
            color: Color(0xFF08734A),
            size: 20,
          ),
        ],
      ),
    );
  }
}
