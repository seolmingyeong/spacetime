import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../room/room_dashboard_screen.dart';
import '../profile/friends_screen.dart';

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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        SupabaseRepository().getNotifications(),
        SupabaseRepository().getRoomInvitations(),
        SupabaseRepository().getRooms(),
      ]);

      if (!mounted) return;

      setState(() {
        _items = values[0] as List<Map<String, dynamic>>;
        _invites = values[1] as List<Map<String, dynamic>>;
        _roomNames = {
          for (final r in values[2] as List<TravelRoom>) r.id: r.name,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  /// 알림의 route 또는 data에서 room_id를 찾는다.
  String? _roomIdOf(Map<String, dynamic> item) {
    final data = item['data'];

    if (data is Map && data['room_id'] != null) {
      return data['room_id'].toString();
    }

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

  /// 친구 요청 관련 알림인지 확인한다.
  ///
  /// request_id가 있다고 해서 무조건 현재 대기 중인 요청은 아니다.
  /// 수락/거절이 완료된 과거 요청에도 request_id가 남아 있을 수 있으므로
  /// 실제 대기 중인 요청인지는 _onNotificationTap에서 다시 확인한다.
  bool _isFriendRequestNotification(Map<String, dynamic> item) {
    final route = item['route']?.toString() ?? '';

    return route.startsWith('/friends') &&
        item['data'] is Map &&
        (item['data'] as Map)['request_id'] != null;
  }

  /// 현재도 수락 대기 중인 친구 요청인지 확인한다.
  Future<bool> _isPendingFriendRequest(String requestId) async {
    final requests = await SupabaseRepository().getFriendRequests();

    return requests.any(
      (request) => request['id'].toString() == requestId,
    );
  }

  Future<void> _onNotificationTap(
    Map<String, dynamic> item,
  ) async {
    if (_isFriendRequestNotification(item)) {
      final requestId =
          (item['data'] as Map)['request_id'].toString();

      try {
        final isPending =
            await _isPendingFriendRequest(requestId);

        if (isPending) {
          // 현재도 수락 대기 중인 요청이면
          // 수락/거절 다이얼로그를 보여준다.
          final action = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                item['title'] ?? '친구 요청',
              ),
              content: Text(
                item['body'] ?? '',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    false,
                  ),
                  child: const Text('거절'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    true,
                  ),
                  child: const Text('수락'),
                ),
              ],
            ),
          );

          if (action != null) {
            await SupabaseRepository()
                .respondFriendRequest(
              requestId,
              action,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    action
                        ? '친구가 되었습니다.'
                        : '친구 요청을 거절했습니다.',
                  ),
                ),
              );
            }
          }
        } else {
          // 이미 수락/거절된 요청이거나
          // 상대방이 내 친구 요청을 수락했다는 알림 등
          // 더 이상 처리할 요청이 없는 경우에는
          // 친구 화면으로 이동한다.
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FriendsScreen(),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
            ),
          );
        }
      }
    } else {
      final roomId = _roomIdOf(item);

      if (roomId != null) {
        try {
          final room =
              await SupabaseRepository().getRoom(roomId);

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RoomDashboardScreen(
                  room: room,
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '이미 삭제되었거나 존재하지 않는 방입니다.',
                ),
              ),
            );
          }
        }
      }
    }

    try {
      await SupabaseRepository().markNotificationRead(
        item['id'].toString(),
      );
    } catch (_) {
      // 알림 읽음 처리 실패가 화면 이동을 막지는 않는다.
    }

    if (mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseRepository()
                  .markAllNotificationsRead();

              _load();
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_invites.isNotEmpty) ...[
                    const Text(
                      '방 초대',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._invites.map(
                      (invite) => Card(
                        child: ListTile(
                          title: Text(
                            invite['room_name'] ?? '',
                          ),
                          subtitle: Text(
                            '${invite['inviter_name']}님의 초대 · ${_duration(invite)}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  await SupabaseRepository()
                                      .respondRoomInvitation(
                                    invite['id'].toString(),
                                    false,
                                  );

                                  _load();
                                },
                                icon: const Icon(
                                  Icons.close,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await SupabaseRepository()
                                      .respondRoomInvitation(
                                    invite['id'].toString(),
                                    true,
                                  );

                                  _load();
                                },
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
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
                      child: Center(
                        child: Text(
                          '새로운 알림이 없습니다.',
                        ),
                      ),
                    ),
                  ..._items.map(
                    (item) {
                      final roomName =
                          _roomNameOf(item);

                      return Card(
                        color: item['read_at'] == null
                            ? AppColors.schedule
                                .withOpacity(.06)
                            : null,
                        child: ListTile(
                          leading:
                              _isFriendRequestNotification(
                            item,
                          )
                                  ? const Icon(
                                      Icons.person_add,
                                      color:
                                          AppColors.profile,
                                    )
                                  : (roomName != null
                                      ? const Icon(
                                          Icons.groups,
                                          color:
                                              AppColors.room,
                                        )
                                      : null),
                          title: Text(
                            item['title'] ?? '',
                          ),
                          subtitle: Text(
                            '${roomName != null ? '[$roomName] ' : ''}'
                            '${item['body'] ?? ''}\n'
                            '${DateFormat('M/d HH:mm').format(
                              DateTime.parse(
                                item['created_at'],
                              ),
                            )}',
                          ),
                          isThreeLine: true,
                          onTap: () =>
                              _onNotificationTap(item),
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