import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'room_create_screen.dart';
import 'room_dashboard_screen.dart';

/// 방 목록: 참여 중인 방 목록 + 새 방 만들기 / 방 입장(초대코드).
/// TODO(team): Supabase room_members 테이블 조회로 교체.
class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key});

  // 목업 데이터 (팀원 연동 전까지 UI 확인용)
  static final _mockRooms = <TravelRoom>[
    TravelRoom(id: '1', name: '제주도 여름 여행', memberCount: 4, status: RoomStatus.planning),
    TravelRoom(id: '2', name: '부산 1박 2일', memberCount: 3, status: RoomStatus.traveling),
    TravelRoom(id: '3', name: '작년 여수 여행', memberCount: 5, status: RoomStatus.completed),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방 목록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: '초대코드로 입장',
            onPressed: () {
              // TODO(team): 초대코드 입력 다이얼로그
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.room,
        icon: const Icon(Icons.add),
        label: const Text('새 방 만들기'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoomCreateScreen()),
          );
        },
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mockRooms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final room = _mockRooms[i];
          return _RoomCard(
            room: room,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: room)),
            ),
          );
        },
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final TravelRoom room;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.onTap});

  String _statusLabel(RoomStatus s) {
    switch (s) {
      case RoomStatus.planning:
        return '계획중';
      case RoomStatus.traveling:
        return '여행중';
      case RoomStatus.completed:
        return '완료';
    }
  }

  Color _statusColor(RoomStatus s) {
    switch (s) {
      case RoomStatus.planning:
        return AppColors.schedule;
      case RoomStatus.traveling:
        return AppColors.record;
      case RoomStatus.completed:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('멤버 ${room.memberCount}명',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(room.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(room.status),
                  style: TextStyle(color: _statusColor(room.status), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
