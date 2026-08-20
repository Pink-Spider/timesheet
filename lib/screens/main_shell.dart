import 'package:flutter/material.dart';

import '../widgets/ad_banner.dart';
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
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                CalendarScreen(),
                StatsScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          // 광고 정책: 체류형 화면인 달력(1)·통계(2) 탭에서만 배너 노출.
          // 트리에서 아예 제거해야 숨은 광고가 노출로 집계되는 일이 없다.
          if (_index == 1 || _index == 2) const AdBanner(),
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
