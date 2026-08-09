import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../notification/notification_screen.dart';
import '../record/record_detail_screen.dart';
import '../room/room_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  const HomeScreen({super.key, required this.onSelectTab});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  List<TravelRoom> _rooms = [];
  List<PersonalSchedule> _personal = [];
  List<RecordAlbum> _allAlbums = [];
  List<RecordAlbum> _myAlbums = [];
  List<Map<String, dynamic>> _tasks = [];
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    final repo = SupabaseRepository();
    final now = DateTime.now();
    final to = now.add(const Duration(days: 30));
    try {
      final values = await Future.wait([
      repo.getMyProfile(),
      repo.getRooms(),
      repo.getPersonalSchedules(now, to),
      repo.getAlbums(
        from: now.subtract(const Duration(days: 30)), 
        to: to
      ),
      repo.getMyAlbums(
        from: now.subtract(const Duration(days: 30)), 
        to: to
      ),
      repo.getNotifications(),
      ]);
      final rooms = values[1] as List<TravelRoom>;
      final tasks = <Map<String, dynamic>>[];
      for (final room in rooms.where((room) => !room.isScheduleFinalized)) {
        final availability = await repo.getAllAvailabilities(room.id);
        final submitted = availability.any(
          (item) => item.userId == repo.currentUserId && item.submitted,
        );
        if (!submitted) {
          tasks.add({'room': room, 'text': '${room.name}의 가능한 날짜를 선택해 주세요'});
        } else if (room.schedulePhase == 'approval') {
          tasks.add({'room': room, 'text': '${room.name}의 날짜 후보에 동의해 주세요'});
        } else if (room.schedulePhase == 'voting') {
          tasks.add({'room': room, 'text': '${room.name}의 날짜 후보에 투표해 주세요'});
        }
      }
      if (mounted) {
        setState(() {
          _profile = values[0] as UserProfile;
          _rooms = rooms;
          _personal = values[2] as List<PersonalSchedule>;
          _allAlbums = (values[3] as List<RecordAlbum>).take(3).toList();
          _myAlbums = (values[4] as List<RecordAlbum>).take(3).toList();
          _tasks = tasks;
          _unread = (values[5] as List<Map<String, dynamic>>).where((item) => item['read_at'] == null).length;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('홈 정보를 불러오지 못했습니다: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile == null ? '홈' : '안녕하세요, ${_profile!.nickname}님'),
        actions: [
          Badge(
            isLabelVisible: _unread > 0,
            label: Text('$_unread'),
            child: IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ).then((_) => reload()),
              icon: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _nextCard(),
                  if (_tasks.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _header('해야 할 일', AppColors.schedule),
                    ..._tasks.map(
                      (task) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.task_alt, color: AppColors.schedule),
                          title: Text(task['text']),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: task['room'])),
                          ).then((_) => reload()),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _header('참여 중인 방', AppColors.room, more: () => widget.onSelectTab(2)),
                  if (_rooms.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('참여 중인 방이 없습니다.'))),
                  ..._rooms.take(3).map(
                    (room) => Card(
                      child: ListTile(
                        title: Text(room.name),
                        subtitle: Text(
                          '${room.memberCount}명 · ${room.tripDurationLabel} · '
                          '${room.isScheduleFinalized ? '일정 확정' : '조율 중'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: room)),
                        ).then((_) => reload()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _header('최근 기록', AppColors.record, more: () => widget.onSelectTab(3)),
                  
                  const SizedBox(height: 8),

                  DefaultTabController(
                    length: 2,
                    child: SizedBox(
                      height: 250,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: AppColors.record,
                            tabs: [
                              Tab(text: '전체 기록'),
                              Tab(text: '내 기록'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _recordList(_allAlbums),
                                _recordList(_myAlbums),
                              ],
                            ), 
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 18),
                  _header('빠른 실행', AppColors.profile),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(avatar: const Icon(Icons.event), label: const Text('개인 일정'), onPressed: () => widget.onSelectTab(1)),
                      ActionChip(avatar: const Icon(Icons.add_home), label: const Text('방 만들기'), onPressed: () => widget.onSelectTab(2)),
                      ActionChip(avatar: const Icon(Icons.photo_camera), label: const Text('기록 작성'), onPressed: () => widget.onSelectTab(3)),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _nextCard() {
    final now = DateTime.now();
    final items = <Map<String, dynamic>>[];
    for (final item in _personal) {
      items.add({
        'date': item.scheduleDate,
        'title': item.title,
        'sub': item.isAllDay ? '종일' : item.scheduleTime?.substring(0, 5) ?? '',
      });
    }
    for (final room in _rooms.where(
      (room) => room.startDate != null && !room.startDate!.isBefore(DateTime(now.year, now.month, now.day)),
    )) {
      items.add({'date': room.startDate!, 'title': room.name, 'sub': room.tripDurationLabel});
    }
    items.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    if (items.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('다가오는 일정이 없습니다.')));
    }
    final item = items.first;
    final date = item['date'] as DateTime;
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return Card(
      color: AppColors.schedule.withOpacity(.08),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('다음 일정', style: TextStyle(color: AppColors.schedule, fontWeight: FontWeight.bold)),
            Text(item['title'], style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            Text('${DateFormat('M월 d일').format(date)} · ${item['sub']} · ${diff == 0 ? '오늘' : 'D-$diff'}'),
          ],
        ),
      ),
    );
  }

  Widget _recordList(List<RecordAlbum> albums) {
    if (albums.isEmpty) {
      return const Center(
        child: Text('최근 기록이 없습니다.'),
      );
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];

          return Card(
            child: ListTile(
              leading: album.coverUrl == null
                  ? const Icon(Icons.photo_album, color: AppColors.record)
                  : Image.network(album.coverUrl!, width: 48, height: 48, fit: BoxFit.cover),
              title: Text(album.title),
              subtitle: Text(DateFormat('yyyy.MM.dd').format(album.recordDate)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecordDetailScreen(album: album)),
              ),
            ),
          );
      },
    );
  }

  Widget _header(String title, Color color, {VoidCallback? more}) {
    return Row(
      children: [
        Container(width: 4, height: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (more != null) TextButton(onPressed: more, child: const Text('전체 보기')),
      ],
    );
  }
}
