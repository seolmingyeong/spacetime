import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// 내 일정: 캘린더 뷰(월별) + 일정 리스트 + 투표/확정 상태 표시.
/// TODO(team): table_calendar 등으로 실제 캘린더 UI 교체, Supabase schedules 연동.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

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
      date: DateTime.now().add(const Duration(days: 4)),
      title: '성산일출봉 방문',
      location: '성산일출봉',
      status: ScheduleStatus.voting,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 일정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {
              // TODO(team): 월별 캘린더 화면으로 전환
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mockSchedules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = _mockSchedules[i];
          final isConfirmed = s.status == ScheduleStatus.confirmed;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.schedule.withOpacity(0.12),
                child: Icon(Icons.event, color: AppColors.schedule),
              ),
              title: Text(s.title),
              subtitle: Text(
                '${DateFormat('M월 d일 (E)', 'ko_KR').format(s.date)}'
                '${s.location != null ? ' · ${s.location}' : ''}',
              ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.schedule,
        child: const Icon(Icons.add),
        onPressed: () {
          // TODO(team): 일정 생성 화면 (날짜/시간/제목 입력)
        },
      ),
    );
  }
}
