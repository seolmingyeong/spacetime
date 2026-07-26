import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// 프로필: 내 정보 / 친구 관리 / 설정.
/// 친구 추가는 ID 검색 / 개인 코드 공유 / 초대 링크 3가지 방식 지원 예정(플로우차트 참고).
/// TODO(team): Supabase profiles/friends 테이블 연동.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 32, backgroundColor: AppColors.divider),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('닉네임', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('user@example.com', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _MenuSection(title: '친구 관리', items: [
            _MenuItemData(icon: Icons.person_search, label: '친구 ID 검색'),
            _MenuItemData(icon: Icons.qr_code, label: '내 개인 코드 공유'),
            _MenuItemData(icon: Icons.link, label: '초대 링크 생성'),
            _MenuItemData(icon: Icons.group, label: '친구 목록'),
          ]),
          const SizedBox(height: 16),
          _MenuSection(title: '설정', items: [
            _MenuItemData(icon: Icons.tune, label: '알림 설정'),
            _MenuItemData(icon: Icons.lock_outline, label: '개인정보 설정'),
            _MenuItemData(icon: Icons.logout, label: '로그아웃'),
          ]),
        ],
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  _MenuItemData({required this.icon, required this.label});
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItemData> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                ListTile(
                  leading: Icon(items[i].icon, color: AppColors.profile),
                  title: Text(items[i].label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO(team): 각 메뉴 세부 화면/로직 연결
                  },
                ),
                if (i != items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
