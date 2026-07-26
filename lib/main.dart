import 'package:flutter/material.dart';

void main() {
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

  final List<PrayerItem> prayers = const [
    PrayerItem(
      englishName: 'Fajr',
      arabicName: 'الفجر',
      time: '04:12 AM',
      icon: Icons.wb_twilight_rounded,
    ),
    PrayerItem(
      englishName: 'Dhuhr',
      arabicName: 'الظهر',
      time: '12:30 PM',
      icon: Icons.wb_sunny_outlined,
      isNext: true,
    ),
    PrayerItem(
      englishName: 'Asr',
      arabicName: 'العصر',
      time: '03:53 PM',
      icon: Icons.sunny_snowing,
    ),
    PrayerItem(
      englishName: 'Maghrib',
      arabicName: 'المغرب',
      time: '06:45 PM',
      icon: Icons.wb_twilight,
    ),
    PrayerItem(
      englishName: 'Isha',
      arabicName: 'العشاء',
      time: '08:15 PM',
      icon: Icons.dark_mode_outlined,
    ),
  ];

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
            onTap: () {},
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Makkah, Saudi Arabia',
                  style: TextStyle(
                    color: Color(0xFF1E2924),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '21.4225° N, 39.8262° E',
                  style: TextStyle(color: Color(0xFF7B847F), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF075B3A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: _whiteCardDecoration(),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '15 Dhul Qadah 1445 AH',
                  style: TextStyle(
                    color: Color(0xFF26332D),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Friday',
                  style: TextStyle(color: Color(0xFF7A837E), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.calendar_month_outlined, color: Color(0xFF0A754B)),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '24 May 2024',
                style: TextStyle(
                  color: Color(0xFF26332D),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Dhuhr',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 10),
                  Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Text(
                      '/ الظهر',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Color(0xFFE8C76F),
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'In 01:48:36',
                style: TextStyle(
                  color: Color(0xFFF4D675),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Prayer time 12:30 PM',
                style: TextStyle(color: Color(0xFFD7E8DE), fontSize: 13),
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
              _PrayerRow(prayer: prayer),
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
                  'Indeed, prayer has been decreed upon the believers at specified times.',
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
  final String time;
  final IconData icon;
  final bool isNext;

  const PrayerItem({
    required this.englishName,
    required this.arabicName,
    required this.time,
    required this.icon,
    this.isNext = false,
  });
}

class _PrayerRow extends StatelessWidget {
  final PrayerItem prayer;

  const _PrayerRow({required this.prayer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: prayer.isNext
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: prayer.isNext
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
            color: prayer.isNext
                ? const Color(0xFF08734A)
                : const Color(0xFF709086),
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
                    fontWeight: prayer.isNext
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ ${prayer.arabicName}',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: prayer.isNext
                        ? const Color(0xFF08734A)
                        : const Color(0xFF6D7671),
                    fontSize: 15,
                    fontWeight: prayer.isNext
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            prayer.time,
            style: TextStyle(
              color: const Color(0xFF1F2A25),
              fontSize: 14,
              fontWeight: prayer.isNext ? FontWeight.w700 : FontWeight.w600,
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
