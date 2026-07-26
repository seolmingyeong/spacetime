import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// 내 일정: 월별 캘린더 뷰 + 선택한 날짜의 일정 리스트.
/// 날짜에 일정이 있으면 점(marker)으로 표시하고, 날짜를 탭하면 아래 리스트가 바뀝니다.
/// TODO(team): Supabase schedules 테이블 연동 (room_id 필터, 실시간 구독 등).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 목업 데이터: 날짜별 일정 목록 (팀원 연동 전까지 UI 확인용)
  static final _mockSchedules = <ScheduleItem>[
    ScheduleItem(
      id: '1',
      roomId: '1',
      date: DateTime.now().add(const Duration(days: 3)),
      title: '제주 공항 도착',
      location: '제주국제공항',
      status: ScheduleStatus.confirmed,
    ),
    ScheduleItem(
      id: '2',
      roomId: '1',
      date: DateTime.now().add(const Duration(days: 3)),
      title: '숙소 체크인',
      location: '제주 게스트하우스',
      status: ScheduleStatus.confirmed,
    ),
    ScheduleItem(
      id: '3',
      roomId: '1',
      date: DateTime.now().add(const Duration(days: 4)),
      title: '성산일출봉 방문',
      location: '성산일출봉',
      status: ScheduleStatus.voting,
    ),
  ];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<ScheduleItem> _schedulesForDay(DateTime day) {
    return _mockSchedules.where((s) => _isSameDay(s.date, day)).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final selectedSchedules =
        _selectedDay != null ? _schedulesForDay(_selectedDay!) : <ScheduleItem>[];

    return Scaffold(
      appBar: AppBar(title: const Text('내 일정')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: TableCalendar<ScheduleItem>(
              locale: 'ko_KR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  _selectedDay != null && _isSameDay(_selectedDay!, day),
              calendarFormat: _calendarFormat,
              eventLoader: _schedulesForDay,
              onFormatChanged: (format) => setState(() => _calendarFormat = format),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) => _focusedDay = focused,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppColors.divider,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.schedule,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: AppColors.record,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: selectedSchedules.isEmpty
                ? const Center(
                    child: Text('선택한 날짜에 일정이 없어요',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: selectedSchedules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = selectedSchedules[i];
                      final isConfirmed = s.status == ScheduleStatus.confirmed;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.schedule.withOpacity(0.12),
                            child: const Icon(Icons.event, color: AppColors.schedule),
                          ),
                          title: Text(s.title),
                          subtitle: s.location != null ? Text(s.location!) : null,
                          trailing: Chip(
                            label: Text(isConfirmed ? '확정' : '투표중'),
                            backgroundColor: isConfirmed
                                ? AppColors.room.withOpacity(0.12)
                                : AppColors.record.withOpacity(0.12),
                            labelStyle: TextStyle(
                              color: isConfirmed ? AppColors.room : AppColors.record,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.schedule,
        onPressed: () {
          // TODO(team): 일정 생성 화면 (선택된 날짜를 기본값으로 전달)
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
