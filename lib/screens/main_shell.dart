import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          CalendarScreen(),
          StatsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), label: '달력'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: '통계'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: '설정'),
        ],
      ),
    );
  }
}
