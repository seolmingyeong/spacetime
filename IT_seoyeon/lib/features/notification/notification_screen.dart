import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../room/room_dashboard_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _invites = [];
  Map<String, String> _roomNames = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final values = await Future.wait([
      SupabaseRepository().getNotifications(),
      SupabaseRepository().getRoomInvitations(),
      SupabaseRepository().getRooms(),
    ]);
    if (mounted) {
      setState(() {
        _items = values[0] as List<Map<String, dynamic>>;
        _invites = values[1] as List<Map<String, dynamic>>;
        _roomNames = {
          for (final r in values[2] as List<TravelRoom>) r.id: r.name,
        };
        _loading = false;
      });
    }
  }

  /// 알림의 route 또는 data에서 관련 room_id를 뽑아낸다.
  /// (/room/{id} 형태의 route를 쓰는 모든 알림 종류에 공통으로 동작)
  String? _roomIdOf(Map<String, dynamic> item) {
    final data = item['data'];
    if (data is Map && data['room_id'] != null) return data['room_id'].toString();
    final route = item['route']?.toString() ?? '';
    final match = RegExp(r'^/room/([^/]+)').firstMatch(route);
    return match?.group(1);
  }

  String? _roomNameOf(Map<String, dynamic> item) {
    final id = _roomIdOf(item);
    if (id == null) return null;
    return _roomNames[id];
  }

  String _duration(Map<String, dynamic> invite) {
    final days = (invite['trip_days'] ?? 1) as int;
    return days == 1 ? '당일치기' : '${days - 1}박 $days일';
  }

  bool _isFriendRequestNotification(Map<String, dynamic> item) {
    final route = item['route']?.toString() ?? '';

    return route.startsWith('/friends') &&
      item['data'] is Map &&
      (item['data'] as Map)['request_id'] != null;
  }
  
  Future<void> _onNotificationTap(Map<String, dynamic> item) async {
    if (_isFriendRequestNotification(item)) {
      final requestId = (item['data'] as Map)['request_id'].toString();
      final action = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(item['title'] ?? '친구 요청'),
          content: Text(item['body'] ?? ''),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('거절')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('수락')),
          ],
        ),
      );
      if (action != null) {
        try {
          await SupabaseRepository().respondFriendRequest(requestId, action);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(action ? '친구가 되었습니다.' : '요청을 거절했습니다.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }
      }
    } else {
      final roomId = _roomIdOf(item);
      if (roomId != null) {
        try {
          final room = await SupabaseRepository().getRoom(roomId);
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: room)),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('방 정보를 불러오지 못했습니다: $e')),
            );
          }
        }
      }
    }
    await SupabaseRepository().markNotificationRead(item['id'].toString());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseRepository().markAllNotificationsRead();
              _load();
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_invites.isNotEmpty) ...[
                    const Text('방 초대', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._invites.map(
                      (invite) => Card(
                        child: ListTile(
                          title: Text(invite['room_name'] ?? ''),
                          subtitle: Text('${invite['inviter_name']}님의 초대 · ${_duration(invite)}'),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  await SupabaseRepository().respondRoomInvitation(invite['id'].toString(), false);
                                  _load();
                                },
                                icon: const Icon(Icons.close),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await SupabaseRepository().respondRoomInvitation(invite['id'].toString(), true);
                                  _load();
                                },
                                icon: const Icon(Icons.check, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_items.isEmpty && _invites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(50),
                      child: Center(child: Text('새 알림이 없습니다.')),
                    ),
                  ..._items.map(
                    (item) {
                      final roomName = _roomNameOf(item);
                      return Card(
                        color: item['read_at'] == null ? AppColors.schedule.withOpacity(.06) : null,
                        child: ListTile(
                          leading: _isFriendRequestNotification(item)
                              ? const Icon(Icons.person_add, color: AppColors.profile)
                              : (roomName != null
                                  ? const Icon(Icons.groups, color: AppColors.room)
                                  : null),
                          title: Text(item['title'] ?? ''),
                          subtitle: Text(
                            '${roomName != null ? '[$roomName] ' : ''}${item['body'] ?? ''}\n'
                            '${DateFormat('M/d HH:mm').format(DateTime.parse(item['created_at']))}',
                          ),
                          isThreeLine: true,
                          onTap: () => _onNotificationTap(item),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}