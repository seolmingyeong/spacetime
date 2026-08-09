import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/record/record_screen.dart';
import '../features/room/room_list_screen.dart';
import '../features/schedule/schedule_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _home = GlobalKey<HomeScreenState>();
  final _schedule = GlobalKey<ScheduleScreenState>();
  final _records = GlobalKey<RecordScreenState>();
  final _profile = GlobalKey<ProfileScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _home, onSelectTab: _select),
      ScheduleScreen(key: _schedule),
      const RoomListScreen(),
      RecordScreen(key: _records),
      ProfileScreen(key: _profile),
    ];
  }

  void _select(int index) {
    setState(() => _index = index);
    if (index == 0) _home.currentState?.reload();
    if (index == 1) _schedule.currentState?.reload();
    if (index == 3) _records.currentState?.reload();
    if (index == 4) _profile.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _select,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: [
          AppColors.schedule,
          AppColors.schedule,
          AppColors.room,
          AppColors.record,
          AppColors.profile,
        ][_index],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note), label: '일정'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: '방'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: '기록'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}
