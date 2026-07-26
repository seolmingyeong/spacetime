import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// HOME: 참여 중인 방 / 다가오는 일정 / 최근 기록 요약.
/// TODO(team): 각 섹션을 Supabase 쿼리로 교체.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: '참여 중인 방', color: AppColors.room),
          const SizedBox(height: 8),
          const _EmptyPlaceholder(text: '아직 참여 중인 방이 없어요'),
          const SizedBox(height: 24),
          _SectionHeader(title: '다가오는 일정', color: AppColors.schedule),
          const SizedBox(height: 8),
          const _EmptyPlaceholder(text: '예정된 일정이 없어요'),
          const SizedBox(height: 24),
          _SectionHeader(title: '최근 기록', color: AppColors.record),
          const SizedBox(height: 8),
          const _EmptyPlaceholder(text: '최근 기록이 없어요'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String text;
  const _EmptyPlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
