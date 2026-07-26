import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// 새 방 만들기: 방 이름 설정 (+ 초대코드 생성은 서버에서 처리).
/// TODO(team): Supabase rooms 테이블 insert 로직 연결.
class RoomCreateScreen extends StatefulWidget {
  const RoomCreateScreen({super.key});

  @override
  State<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends State<RoomCreateScreen> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 방 만들기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '방 이름',
                hintText: '예: 제주도 여름 여행',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.room,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                // TODO(team): 방 생성 API 호출 후 RoomDashboardScreen 으로 이동
                Navigator.of(context).pop();
              },
              child: const Text('방 만들기'),
            ),
          ],
        ),
      ),
    );
  }
}
