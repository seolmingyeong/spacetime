import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../features/home/home_screen.dart';
import '../features/room/room_list_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/profile/profile_screen.dart';

/// 이미지 3번(하단 네비게이션: 홈 / 방 / 일정 / 프로필)을 그대로 구현한 메인 셸.
/// 어느 탭에서든 즉시 다른 탭으로 이동 가능하도록 IndexedStack으로 상태를 유지합니다.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    RoomListScreen(),
    ScheduleScreen(),
    ProfileScreen(),
  ];

  final _tabs = const [
    _TabInfo(icon: Icons.home_rounded, label: '홈'),
    _TabInfo(icon: Icons.groups_rounded, label: '방'),
    _TabInfo(icon: Icons.event_note_rounded, label: '일정'),
    _TabInfo(icon: Icons.person_rounded, label: '프로필'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.schedule,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        items: [
          for (final tab in _tabs)
            BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String label;
  const _TabInfo({required this.icon, required this.label});
}
