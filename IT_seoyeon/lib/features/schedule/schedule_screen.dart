import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../record/record_detail_screen.dart';
import '../room/room_dashboard_screen.dart';
import 'personal_schedule_edit_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  List<TravelRoom> _rooms = [];
  List<PersonalSchedule> _personal = [];
  List<RecordAlbum> _albums = [];
  bool _loading = true;

  // 방마다 다른 색을 배정하기 위한 팔레트. 방 이름을 해시해서 같은 방은 항상 같은 색을 갖도록 한다.
  static const List<Color> _roomPalette = [
    Color(0xFFFF8A65), // 코랄
    Color(0xFF4FC3F7), // 스카이블루
    Color(0xFFBA68C8), // 라벤더
    Color(0xFF81C784), // 민트그린
    Color(0xFFFFB74D), // 앰버
    Color(0xFF64B5F6), // 블루
    Color(0xFFF06292), // 핑크
    Color(0xFF4DB6AC), // 틸
  ];

  Color _roomColor(TravelRoom room) {
    return _roomPalette[room.name.hashCode.abs() % _roomPalette.length];
  }

  /// 이벤트 카드 왼쪽에 쓰는 동그란 아이콘 배경. 옅은 색 원 위에 진한 아이콘을 얹어
  /// 어떤 종류의 일정인지, 어떤 방의 일정인지 한눈에 구분되게 한다.
  Widget _leadingAvatar(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color.withOpacity(.14), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    );
  }

  /// 마커용 작은 점. 개인 일정/기록 색을 구분해서 보여줄 때 쓴다.
  Widget _dot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _within(DateTime date, DateTime start, DateTime end) {
    final value = DateTime(date.year, date.month, date.day);
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    return !value.isBefore(first) && !value.isAfter(last);
  }

  /// 해당 날짜가 포함된 여행 일정을 찾는다 (달력에 이어진 띠로 표시하기 위함).
  TravelRoom? _tripOn(DateTime date) {
    for (final room in _rooms) {
      if (room.startDate == null) continue;
      if (_within(date, room.startDate!, room.endDate ?? room.startDate!)) return room;
    }
    return null;
  }

  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    final from = DateTime(_focused.year, _focused.month - 1, 1);
    final to = DateTime(_focused.year, _focused.month + 2, 0);
    try {
      final values = await Future.wait([
        SupabaseRepository().getRooms(),
        SupabaseRepository().getPersonalSchedules(from, to),
        SupabaseRepository().getAlbums(from: from, to: to),
      ]);
      if (mounted) {
        setState(() {
          _rooms = (values[0] as List<TravelRoom>).where((room) => room.isScheduleFinalized).toList();
          _personal = values[1] as List<PersonalSchedule>;
          _albums = values[2] as List<RecordAlbum>;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정을 불러오지 못했습니다: $error')),
      );
    }
  }

  List<Object> _events(DateTime date) {
    return [
      ..._rooms.where((room) => room.startDate != null && _within(date, room.startDate!, room.endDate ?? room.startDate!)),
      ..._personal.where((item) => _same(item.scheduleDate, date)),
      ..._albums.where((album) => _same(album.recordDate, date)),
    ];
  }

  Future<void> _edit([PersonalSchedule? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PersonalScheduleEditScreen(initialDate: _selected, item: item)),
    );
    if (changed == true) reload();
  }

  Widget _eventCard(Object event) {
    if (event is PersonalSchedule) {
      // 개인 일정은 왼쪽에 얇은 컬러 스트라이프를 둬서 방 일정·기록과 확실히 구분되게 한다.
      return Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: AppColors.schedule),
              Expanded(
                child: ListTile(
                  leading: _leadingAvatar(Icons.event, AppColors.schedule),
                  title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(event.isAllDay ? '종일' : event.scheduleTime?.substring(0, 5) ?? '시간 미정'),
                  onTap: () => _edit(event),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (event is TravelRoom) {
      final color = _roomColor(event);
      return Card(
        child: ListTile(
          leading: _leadingAvatar(Icons.groups, color),
          title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${event.tripDurationLabel} · ${event.tripDateRangeLabel}',
          ),
          trailing: Icon(Icons.chevron_right, color: color),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: event, initialTab: 0)),
          ),
        ),
      );
    }
    final album = event as RecordAlbum;
    return Card(
      child: ListTile(
        leading: album.coverUrl == null
            ? _leadingAvatar(Icons.photo_album, AppColors.record)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(album.coverUrl!, width: 44, height: 44, fit: BoxFit.cover),
              ),
        title: Text(album.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('사진 ${album.photoCount}장'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecordDetailScreen(album: album)),
        ),
      ),
    );
  }

  /// 날짜 셀 하나를 그린다.
  /// - 여행 기간에 속하면 해당 방의 색으로 옅은 캡슐형 띠를 그려 며칠에 걸친 일정임을 보여주고,
  ///   시작일·종료일에는 그 방 색으로 꽉 찬 원(포인트)을 얹어 시선을 붙잡는다.
  ///   중간일들은 띠 위에 방 색 굵은 숫자만 얹어 심플하게 표시한다.
  /// - 선택됨/오늘 표시는 그 위에 원으로 얹는다(선택 시 여행 중이면 방 색을 그대로 사용).
  /// - 특별히 표시할 게 없으면 null을 반환해 테이블 기본 렌더링을 그대로 쓴다.
  Widget? _dayCell(DateTime day, {bool selected = false, bool today = false}) {
    final trip = _tripOn(day);
    final tripColor = trip != null ? _roomColor(trip) : null;
    final isTripEdge = trip != null &&
        (_same(day, trip.startDate!) || _same(day, trip.endDate ?? trip.startDate!));

    // 우선순위: 선택됨 > 오늘 > 여행 시작/종료일(포인트) > 여행 중간일 > 기본
    Color? circleColor;
    Color? borderColor;
    Color textColor = Colors.black87;
    FontWeight weight = FontWeight.normal;

    if (selected) {
      circleColor = tripColor ?? AppColors.schedule;
      textColor = Colors.white;
      weight = FontWeight.bold;
    } else if (today) {
      borderColor = AppColors.schedule;
      textColor = AppColors.schedule;
      weight = FontWeight.bold;
    } else if (isTripEdge) {
      circleColor = tripColor;
      textColor = Colors.white;
      weight = FontWeight.bold;
    } else if (tripColor != null) {
      textColor = tripColor;
      weight = FontWeight.w600;
    }

    final number = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor, width: 1.4) : null,
      ),
      child: Text('${day.day}', style: TextStyle(fontSize: 14, color: textColor, fontWeight: weight)),
    );

    if (trip == null) {
      return selected || today ? number : null;
    }

    final isStart = _same(day, trip.startDate!);
    final isEnd = _same(day, trip.endDate ?? trip.startDate!);
    // 심플한 연결 띠: 옅게 색을 깐 얇은 캡슐형 바로 여러 날에 걸친 여행임을 보여주고,
    // 시작·종료일에만 진한 원(포인트)을 얹어 시선을 잡는다.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 9),
      height: 34,
      decoration: BoxDecoration(
        color: tripColor!.withOpacity(.14),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(17) : Radius.zero,
          right: isEnd ? const Radius.circular(17) : Radius.zero,
        ),
      ),
      child: Center(child: number),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _events(_selected);
    return Scaffold(
      appBar: AppBar(title: const Text('내 일정')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('개인 일정'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: TableCalendar<Object>(
                      locale: 'ko_KR',
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2035),
                      focusedDay: _focused,
                      selectedDayPredicate: (day) => _same(day, _selected),
                      eventLoader: _events,
                      onDaySelected: (day, focused) => setState(() { _selected = day; _focused = focused; }),
                      onPageChanged: (focused) { _focused = focused; reload(); },
                      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                      calendarStyle: const CalendarStyle(
                        // 마커는 커스텀 markerBuilder에서 그리므로 기본 마커는 끈다.
                        markersMaxCount: 0,
                      ),
                      calendarBuilders: CalendarBuilders<Object>(
                        defaultBuilder: (context, day, focusedDay) => _dayCell(day),
                        todayBuilder: (context, day, focusedDay) => _dayCell(day, today: true),
                        selectedBuilder: (context, day, focusedDay) => _dayCell(day, selected: true),
                        markerBuilder: (context, day, dayEvents) {
                          // 여행 일정은 위의 띠로 이미 표현되니, 개인 일정·기록만 점으로 표시한다.
                          // 두 종류를 서로 다른 색 점으로 그려서 카드 목록과 색을 맞추고,
                          // 달력만 봐도 그날 무슨 종류의 일정이 있는지 구분되게 한다.
                          final hasPersonal = dayEvents.any((e) => e is PersonalSchedule);
                          final hasAlbum = dayEvents.any((e) => e is RecordAlbum);
                          if (!hasPersonal && !hasAlbum) return null;
                          return Positioned(
                            bottom: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasPersonal) _dot(AppColors.schedule),
                                if (hasPersonal && hasAlbum) const SizedBox(width: 3),
                                if (hasAlbum) _dot(AppColors.record),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(_selected),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (events.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('등록된 일정이나 기록이 없습니다.')),
                      ),
                    ),
                  ...events.map(_eventCard),
                ],
              ),
            ),
    );
  }
}