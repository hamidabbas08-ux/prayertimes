import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prayertimes/models/dua_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final Set<String> _favoriteIds = <String>{};

  String _selectedCategory = 'All';
  DuaItem? _selectedDua;

  static const List<String> _categories = [
    'All',
    'Favorites',
    'Daily',
    'Food',
    'Sleep',
    'Home',
    'Mosque',
    'Travel',
  ];

  static const List<DuaItem> _duas = [
    DuaItem(
      id: 'before_eating',
      title: 'Before Eating',
      category: 'Food',
      icon: Icons.restaurant_rounded,
      arabic: 'بِسْمِ اللَّهِ',
      transliteration: 'Bismillah.',
      translation: 'In the name of Allah.',
      reference: 'Sunan Abi Dawud',
    ),
    DuaItem(
      id: 'after_eating',
      title: 'After Eating',
      category: 'Food',
      icon: Icons.restaurant_menu_rounded,
      arabic:
          'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا '
          'وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ',
      transliteration:
          'Alhamdu lillahil-ladhi atamani hadha wa razaqanihi '
          'min ghairi hawlin minni wa la quwwah.',
      translation:
          'Praise is to Allah who gave me this food and provided it '
          'without any power or strength from me.',
      reference: 'Jami at-Tirmidhi',
    ),
    DuaItem(
      id: 'before_sleep',
      title: 'Before Sleeping',
      category: 'Sleep',
      icon: Icons.bedtime_rounded,
      arabic: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
      transliteration: 'Bismika Allahumma amutu wa ahya.',
      translation: 'In Your name, O Allah, I die and I live.',
      reference: 'Sahih al-Bukhari',
    ),
    DuaItem(
      id: 'after_waking',
      title: 'After Waking Up',
      category: 'Sleep',
      icon: Icons.wb_sunny_rounded,
      arabic:
          'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا '
          'أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
      transliteration:
          'Alhamdu lillahil-ladhi ahyana bada ma amatana '
          'wa ilayhin-nushur.',
      translation:
          'Praise is to Allah who gave us life after causing us to die, '
          'and to Him is the resurrection.',
      reference: 'Sahih al-Bukhari',
    ),
    DuaItem(
      id: 'leaving_home',
      title: 'Leaving Home',
      category: 'Home',
      icon: Icons.exit_to_app_rounded,
      arabic:
          'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، '
          'وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      transliteration:
          'Bismillah, tawakkaltu alallah, wa la hawla '
          'wa la quwwata illa billah.',
      translation:
          'In the name of Allah, I trust in Allah. There is no power '
          'and no strength except through Allah.',
      reference: 'Sunan Abi Dawud',
    ),
    DuaItem(
      id: 'entering_home',
      title: 'Entering Home',
      category: 'Home',
      icon: Icons.home_rounded,
      arabic:
          'اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ الْمَوْلَجِ '
          'وَخَيْرَ الْمَخْرَجِ',
      transliteration:
          'Allahumma inni asaluka khairal-mawlaji '
          'wa khairal-makhraji.',
      translation:
          'O Allah, I ask You for the best entrance and the best exit.',
      reference: 'Sunan Abi Dawud',
    ),
    DuaItem(
      id: 'entering_mosque',
      title: 'Entering the Mosque',
      category: 'Mosque',
      icon: Icons.mosque_rounded,
      arabic: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
      transliteration: 'Allahumma-ftah li abwaba rahmatik.',
      translation: 'O Allah, open for me the doors of Your mercy.',
      reference: 'Sahih Muslim',
    ),
    DuaItem(
      id: 'leaving_mosque',
      title: 'Leaving the Mosque',
      category: 'Mosque',
      icon: Icons.door_front_door_rounded,
      arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
      transliteration: 'Allahumma inni asaluka min fadlik.',
      translation: 'O Allah, I ask You from Your bounty.',
      reference: 'Sahih Muslim',
    ),
    DuaItem(
      id: 'travel',
      title: 'Travel Dua',
      category: 'Travel',
      icon: Icons.flight_takeoff_rounded,
      arabic:
          'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا '
          'لَهُ مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ',
      transliteration:
          'Subhanal-ladhi sakhkhara lana hadha wa ma kunna '
          'lahu muqrinin, wa inna ila Rabbina lamunqalibun.',
      translation:
          'Glory is to Him who subjected this to us, though we could '
          'not have controlled it, and to our Lord we will return.',
      reference: 'Quran 43:13–14',
    ),
    DuaItem(
      id: 'forgiveness',
      title: 'Seeking Forgiveness',
      category: 'Daily',
      icon: Icons.favorite_rounded,
      arabic: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
      transliteration: 'Astaghfirullaha wa atubu ilayh.',
      translation: 'I seek Allah’s forgiveness and repent to Him.',
      reference: 'Sahih al-Bukhari',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final stored = await _preferences.getStringList('favorite_duas');

    if (!mounted) return;

    setState(() {
      _favoriteIds
        ..clear()
        ..addAll(stored ?? const <String>[]);
    });
  }

  Future<void> _toggleFavorite(DuaItem dua) async {
    setState(() {
      if (_favoriteIds.contains(dua.id)) {
        _favoriteIds.remove(dua.id);
      } else {
        _favoriteIds.add(dua.id);
      }
    });

    await _preferences.setStringList(
      'favorite_duas',
      _favoriteIds.toList()..sort(),
    );
  }

  Future<void> _copyDua(DuaItem dua) async {
    final text = [
      dua.title,
      '',
      dua.arabic,
      '',
      dua.transliteration,
      '',
      dua.translation,
      '',
      'Reference: ${dua.reference}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${dua.title} copied.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<DuaItem> get _visibleDuas {
    if (_selectedCategory == 'Favorites') {
      return _duas.where((dua) => _favoriteIds.contains(dua.id)).toList();
    }

    if (_selectedCategory == 'All') {
      return _duas;
    }

    return _duas.where((dua) => dua.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dua = _selectedDua;

    if (dua != null) {
      return _buildDetailScreen(dua);
    }

    return _buildLibraryScreen();
  }

  Widget _buildLibraryScreen() {
    final visibleDuas = _visibleDuas;

    return Column(
      children: [
        _buildHeader(title: 'Duas', onBack: null),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              children: [
                _buildHeroCard(),
                const SizedBox(height: 15),
                _buildCategories(),
                const SizedBox(height: 15),
                if (visibleDuas.isEmpty)
                  _buildEmptyCard()
                else
                  ...visibleDuas.map(_buildDuaCard),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required String title, required VoidCallback? onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          if (onBack != null)
            _headerButton(icon: Icons.arrow_back_rounded, onTap: onBack)
          else
            const SizedBox(width: 44),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF075B3A),
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _headerButton({required IconData icon, required VoidCallback onTap}) {
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

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
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
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Duas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Remember Allah throughout your day with '
                  'authentic supplications.',
                  style: TextStyle(
                    color: Color(0xFFD8EAE0),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.auto_stories_rounded, color: Color(0xFFF4D675), size: 58),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 43,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            showCheckmark: false,
            selectedColor: const Color(0xFF087247),
            backgroundColor: const Color(0xFFFFFDF9),
            side: BorderSide(
              color: selected
                  ? const Color(0xFF087247)
                  : const Color(0xFFDDE4DF),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF435049),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) {
              setState(() {
                _selectedCategory = category;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDuaCard(DuaItem dua) {
    final favorite = _favoriteIds.contains(dua.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _selectedDua = dua;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3ED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(dua.icon, color: const Color(0xFF08734A)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dua.title,
                        style: const TextStyle(
                          color: Color(0xFF25312B),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dua.category,
                        style: const TextStyle(
                          color: Color(0xFF77817B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleFavorite(dua),
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: favorite
                        ? const Color(0xFFD2A33A)
                        : const Color(0xFF9AA19D),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF08734A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailScreen(DuaItem dua) {
    final favorite = _favoriteIds.contains(dua.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              _headerButton(
                icon: Icons.arrow_back_rounded,
                onTap: () {
                  setState(() {
                    _selectedDua = null;
                  });
                },
              ),
              Expanded(
                child: Text(
                  dua.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF075B3A),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _toggleFavorite(dua),
                icon: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: favorite
                      ? const Color(0xFFD2A33A)
                      : const Color(0xFF08734A),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF087247), Color(0xFF03472F)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(dua.icon, color: const Color(0xFFF4D675), size: 38),
                      const SizedBox(height: 16),
                      Text(
                        dua.arabic,
                        textAlign: TextAlign.center,
                        textDirection: ui.TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1.9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _textCard(
                  title: 'Transliteration',
                  text: dua.transliteration,
                  icon: Icons.record_voice_over_outlined,
                ),
                const SizedBox(height: 12),
                _textCard(
                  title: 'English Meaning',
                  text: dua.translation,
                  icon: Icons.translate_rounded,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4EE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCFE4D7)),
                  ),
                  child: Text(
                    'Reference: ${dua.reference}',
                    style: const TextStyle(
                      color: Color(0xFF405149),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _copyDua(dua),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy Dua'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087247),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _textCard({
    required String title,
    required String text,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF08734A)),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF075B3A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF38463F),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            color: Color(0xFF9A6A37),
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No favorite Duas yet',
            style: TextStyle(
              color: Color(0xFF25312B),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
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
