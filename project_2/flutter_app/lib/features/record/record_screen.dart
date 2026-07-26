import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// 최상위 "기록" 탭.
/// 참여 중인 모든 방의 기록(사진/메모)을 한 곳에서 모아 보여줍니다.
/// 방 내부에도 그 방만의 기록 탭이 있지만(RoomDashboardScreen), 여기서는
/// 여러 방을 넘나드는 전체 피드 형태로 보여줍니다.
/// TODO(team): Supabase records 테이블에서 내가 속한 room_id 전체를 조회하도록 연결.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  static final _mockRecords = <RecordItem>[
    RecordItem(
      id: '1',
      roomId: '1',
      placeName: '성산일출봉',
      memo: '일출 진짜 예뻤다',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      likeCount: 3,
    ),
    RecordItem(
      id: '2',
      roomId: '2',
      placeName: '해운대 해수욕장',
      memo: '노을 맛집',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      likeCount: 5,
    ),
  ];

  static const _roomNameById = {
    '1': '제주도 여름 여행',
    '2': '부산 1박 2일',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: '방별 필터',
            onPressed: () {
              // TODO(team): 방별로 기록 필터링하는 바텀시트
            },
          ),
        ],
      ),
      body: _mockRecords.isEmpty
          ? const Center(
              child: Text('아직 기록이 없어요', style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _mockRecords.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _RecordCard(record: _mockRecords[i]),
            ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final RecordItem record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final roomName = RecordScreen._roomNameById[record.roomId] ?? '알 수 없는 방';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.record.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(roomName,
                      style: const TextStyle(fontSize: 11, color: AppColors.record, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Text(DateFormat('M월 d일', 'ko_KR').format(record.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            // TODO(team): record.imageUrl 있으면 이미지 표시, Supabase Storage 연동
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 32),
            ),
            const SizedBox(height: 10),
            Text(record.placeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (record.memo != null) ...[
              const SizedBox(height: 4),
              Text(record.memo!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.favorite_border_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${record.likeCount}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                const Icon(Icons.mode_comment_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                const Text('댓글', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
