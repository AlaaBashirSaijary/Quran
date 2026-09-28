import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tabs/ahadeth_tab.dart';
import '../tabs/sebha_tab.dart';
import '../notifications/notification_screen.dart';
import 'azkar_screen.dart';
import 'index_screen.dart';
import 'prayer_screen.dart';
import '../core/language.dart';
import '../providers/sebha_provider.dart';
import '../tabs/volume_keys.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selectedIndex = 0;
  static const _sebhaTab = 3;
  StreamSubscription<void>? _volume;

  @override
  void initState() {
    super.initState();
    _volume = VolumeKeys.presses.listen((_) {
      if (mounted && _selectedIndex == _sebhaTab) {
        countTasbeeh(context.read<SebhaProvider>());
      }
    });
  }

  @override
  void dispose() {
    _volume?.cancel();
    VolumeKeys.capture(false);
    super.dispose();
  }

  static const _tabs = [
    IndexScreen(isTab: true),
    PrayerScreen(),
    AzkarScreen(),
    SebhaTab(),
    AhadithTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final volumeKeys = context.select<SebhaProvider, bool>((s) => s.volumeKeys);
    VolumeKeys.capture(volumeKeys && _selectedIndex == _sebhaTab);
    return NotificationSync(
      child: Scaffold(
        // IndexedStack keeps each tab's state (e.g. the sebha counter)
        body: IndexedStack(index: _selectedIndex, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: [
            NavigationDestination(
              icon: ImageIcon(AssetImage('assets/ic_quran.png')),
              label: tr('القرآن', 'Quran'),
            ),
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque_rounded),
              label: tr('الصلاة', 'Prayer'),
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism_rounded),
              label: tr('الأذكار', 'Azkar'),
            ),
            NavigationDestination(
              icon: ImageIcon(AssetImage('assets/ic_sebha.png')),
              label: tr('السبحة', 'Tasbeeh'),
            ),
            NavigationDestination(
              icon: ImageIcon(AssetImage('assets/ic_ahadeth.png')),
              label: tr('الأحاديث', 'Hadith'),
            ),
          ],
        ),
      ),
    );
  }
}
