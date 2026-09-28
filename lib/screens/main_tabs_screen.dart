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
import '../main.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> with RouteAware {
  int _selectedIndex = 0;
  static const _sebhaTab = 3;
  StreamSubscription<void>? _volume;

  /// False while another screen (the reader, settings...) covers the tabs.
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => setState(() => _visible = false);

  @override
  void didPopNext() => setState(() => _visible = true);

  @override
  void initState() {
    super.initState();
    _volume = VolumeKeys.presses.listen((_) {
      if (mounted && _visible && _selectedIndex == _sebhaTab) {
        countTasbeeh(context.read<SebhaProvider>());
      }
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
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
    VolumeKeys.capture(volumeKeys && _visible && _selectedIndex == _sebhaTab);
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
