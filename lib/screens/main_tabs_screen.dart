import 'package:flutter/material.dart';

import '../tabs/ahadeth_tab.dart';
import '../tabs/sebha_tab.dart';
import 'index_screen.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
    IndexScreen(isTab: true),
    AhadithTab(),
    SebhaTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's state (e.g. the sebha counter)
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: ImageIcon(AssetImage('assets/ic_quran.png')),
            label: 'القرآن',
          ),
          NavigationDestination(
            icon: ImageIcon(AssetImage('assets/ic_ahadeth.png')),
            label: 'الأحاديث',
          ),
          NavigationDestination(
            icon: ImageIcon(AssetImage('assets/ic_sebha.png')),
            label: 'السبحة',
          ),
        ],
      ),
    );
  }
}
