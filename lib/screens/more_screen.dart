import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.locationName,
    required this.coordinatesText,
    required this.enabledPrayerCount,
    required this.isRefreshingLocation,
    required this.isSchedulingAlerts,
    required this.onRefreshLocation,
    required this.onRefreshAzanSchedule,
  });

  final String locationName;
  final String coordinatesText;
  final int enabledPrayerCount;
  final bool isRefreshingLocation;
  final bool isSchedulingAlerts;
  final Future<void> Function() onRefreshLocation;
  final Future<void> Function() onRefreshAzanSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildSectionTitle('Prayer & Azan'),
                const SizedBox(height: 9),
                _buildSettingsCard(
                  children: [
                    _buildActionTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Azan Notifications',
                      subtitle:
                          '$enabledPrayerCount of 5 prayer alerts enabled',
                      trailing: isSchedulingAlerts
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Color(0xFF08734A),
                              ),
                            )
                          : const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF08734A),
                            ),
                      onTap: isSchedulingAlerts
                          ? null
                          : () async {
                              await onRefreshAzanSchedule();
                            },
                    ),
                    const Divider(
                      height: 1,
                      indent: 58,
                      color: Color(0xFFE8E6DF),
                    ),
                    _buildInfoTile(
                      icon: Icons.calculate_outlined,
                      title: 'Calculation Method',
                      value: 'Dubai',
                    ),
                    const Divider(
                      height: 1,
                      indent: 58,
                      color: Color(0xFFE8E6DF),
                    ),
                    _buildInfoTile(
                      icon: Icons.account_balance_outlined,
                      title: 'Asr Calculation',
                      value: 'Shafi',
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                _buildSectionTitle('Location'),
                const SizedBox(height: 9),
                _buildSettingsCard(
                  children: [
                    _buildActionTile(
                      icon: Icons.location_on_outlined,
                      title: locationName,
                      subtitle: coordinatesText.isEmpty
                          ? 'Location is being detected'
                          : coordinatesText,
                      trailing: isRefreshingLocation
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Color(0xFF08734A),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF08734A),
                            ),
                      onTap: isRefreshingLocation
                          ? null
                          : () async {
                              await onRefreshLocation();
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                _buildSectionTitle('App'),
                const SizedBox(height: 9),
                _buildSettingsCard(
                  children: [
                    _buildInfoTile(
                      icon: Icons.language_rounded,
                      title: 'App Language',
                      value: 'English',
                    ),
                    const Divider(
                      height: 1,
                      indent: 58,
                      color: Color(0xFFE8E6DF),
                    ),
                    _buildInfoTile(
                      icon: Icons.schedule_rounded,
                      title: 'Time Format',
                      value: '12-hour',
                    ),
                    const Divider(
                      height: 1,
                      indent: 58,
                      color: Color(0xFFE8E6DF),
                    ),
                    _buildInfoTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Version',
                      value: '1.0.0',
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                _buildAboutCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 19, 18, 13),
      child: Text(
        'More',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF075B3A),
          fontSize: 25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 21),
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
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prayer Times',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage Azan alerts, location and prayer settings.',
                  style: TextStyle(
                    color: Color(0xFFD8EAE0),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14),
          Icon(Icons.settings_rounded, color: Color(0xFFF4D675), size: 56),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF075B3A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required Future<void> Function()? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          child: Row(
            children: [
              _tileIcon(icon),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF27332D),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF77807B),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Row(
        children: [
          _tileIcon(icon),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF27332D),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF08734A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileIcon(IconData icon) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3ED),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: const Color(0xFF08734A), size: 24),
    );
  }

  Widget _buildAboutCard() {
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
          Icon(Icons.mosque_outlined, color: Color(0xFF08734A), size: 29),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Prayer Times provides location-based prayer calculations, '
              'exact Azan alerts, Qibla direction, monthly timetables '
              'and daily Duas.',
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
