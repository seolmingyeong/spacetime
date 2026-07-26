import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// 방 Dashboard: 방 내부 메뉴 (일정 / 장소 / 코스 / 기록 / 멤버).
/// 플로우차트의 "방 내부 메뉴" 탭 구조를 TabBar로 구현.
/// TODO(team): 각 탭에 실제 데이터/AI 추천 API 연결.
class RoomDashboardScreen extends StatelessWidget {
  final TravelRoom room;
  const RoomDashboardScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(room.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                // TODO(team): 방 설정 (멤버 초대/방 이름 변경 등)
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.schedule,
            indicatorColor: AppColors.schedule,
            tabs: [
              Tab(text: '일정'),
              Tab(text: '장소 추천'),
              Tab(text: '코스'),
              Tab(text: '기록'),
              Tab(text: '멤버'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RoomTabPlaceholder(
              label: '일정 관리',
              items: ['일정 생성', '일정 투표', '일정 확정'],
            ),
            _RoomTabPlaceholder(
              label: '장소 추천 (AI)',
              items: ['AI 장소 추천', '장소 검색', '장소 투표'],
            ),
            _RoomTabPlaceholder(
              label: '코스 추천 (AI)',
              items: ['사용자 순서 저장', '최적 경로 계산', '코스 확인'],
            ),
            _RoomTabPlaceholder(
              label: '기록',
              items: ['장소별 기록(사진/메모)', '댓글 작성', '좋아요(담글) 작성'],
            ),
            _RoomTabPlaceholder(
              label: '멤버',
              items: ['멤버 목록', '초대/내보내기', '역할 관리(방장/멤버)'],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTabPlaceholder extends StatelessWidget {
  final String label;
  final List<String> items;
  const _RoomTabPlaceholder({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final item in items)
          Card(
            child: ListTile(
              title: Text(item),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO(team): 세부 기능 화면/API 연결
              },
            ),
          ),
      ],
    );
  }
}
