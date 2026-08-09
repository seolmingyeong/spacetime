import 'package:flutter/material.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'room_create_screen.dart';
import 'room_dashboard_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});
  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  late Future<List<TravelRoom>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseRepository().getRooms();
  }

  Future<void> _refresh() async {
    final nextRequest = SupabaseRepository().getRooms();
    setState(() {
      _future = nextRequest;
    });
    await nextRequest;
  }

  Future<void> _create() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomCreateScreen()));
    _refresh();
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('초대 코드로 입장'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6자리 코드'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim().toUpperCase()),
            child: const Text('입장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.length != 6) return;
    try {
      final room = await SupabaseRepository().joinRoom(code);
      if (!mounted) return;
      if (room == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('일치하는 방이 없습니다.')));
      } else {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: room)));
        _refresh();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방 목록'),
        actions: [
          IconButton(onPressed: _join, icon: const Icon(Icons.qr_code_scanner), tooltip: '초대 코드'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.room,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('새 방 만들기'),
      ),
      body: FutureBuilder<List<TravelRoom>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text('방 목록을 불러오지 못했습니다.'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _refresh, child: const Text('다시 시도')),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rooms = snapshot.data!;
          if (rooms.isEmpty) return const Center(child: Text('참여 중인 방이 없습니다.'));
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final room = rooms[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.room.withOpacity(.12),
                      child: const Icon(Icons.groups, color: AppColors.room),
                    ),
                    title: Text(room.name),
                    subtitle: Text(
                      '${room.memberCount}명 · ${room.tripDurationLabel} · '
                      '${room.isScheduleFinalized ? '일정 확정' : '일정 조율 중'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: room)),
                    ).then((_) => _refresh()),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
