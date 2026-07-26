import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../features/home/home_screen.dart';
import '../features/room/room_list_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/record/record_screen.dart';
import '../features/profile/profile_screen.dart';

/// 하단 네비게이션: 홈 / 일정 / 방 / 기록 / 프로필 (5탭).
/// 기록(Record)이 방 내부 전용이 아니라 최상위 탭으로 승격되어,
/// 참여 중인 모든 방의 기록을 한 곳에서 모아볼 수 있습니다.
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
    ScheduleScreen(),
    RoomListScreen(),
    RecordScreen(),
    ProfileScreen(),
  ];

  final _tabs = const [
    _TabInfo(icon: Icons.home_rounded, label: '홈'),
    _TabInfo(icon: Icons.event_note_rounded, label: '일정'),
    _TabInfo(icon: Icons.groups_rounded, label: '방'),
    _TabInfo(icon: Icons.photo_library_rounded, label: '기록'),
    _TabInfo(icon: Icons.person_rounded, label: '프로필'),
  ];

  static const _tabColors = [
    AppColors.schedule, // 홈
    AppColors.schedule, // 일정
    AppColors.room, // 방
    AppColors.record, // 기록
    AppColors.profile, // 프로필
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _tabColors[_currentIndex],
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
