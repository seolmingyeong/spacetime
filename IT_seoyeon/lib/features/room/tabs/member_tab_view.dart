import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/supabase_repository.dart';
import '../../../core/theme.dart';
import '../../../models/models.dart';

class MemberTabView extends StatefulWidget {
  final TravelRoom room;

  const MemberTabView({
    super.key,
    required this.room,
  });

  @override
  State<MemberTabView> createState() => _MemberTabViewState();
}

class _MemberTabViewState extends State<MemberTabView> {
  final _repo = SupabaseRepository();

  List<RoomMember> _members = [];
  Set<String> _friendIds = {};
  Map<String, String> _incomingRequests = {};
  bool _loading = true;

  bool get _owner =>
      _members.any(
        (m) =>
            m.userId == _repo.currentUserId &&
            m.role == MemberRole.owner,
      );

  bool get _isSolo => widget.room.travelType == 'solo';

  Future<void> _load() async {
    try {
      final m = await _repo.getMembers(widget.room.id);

      Set<String> friendIds = {};

      try {
        final friends = await _repo.getFriends();
        friendIds = friends.map((f) => f.id).toSet();
      } catch (e) {
        debugPrint('친구 목록 로드 실패: $e');
      }

      Map<String, String> incomingRequests = {};

      try {
        final requests = await _repo.getFriendRequests();
        incomingRequests = {
          for (final r in requests)
            r['requester_id'].toString(): r['id'].toString(),
        };
      } catch (e) {
        debugPrint('받은 친구 요청 로드 실패: $e');
      }

      if (mounted) {
        setState(() {
          _members = m;
          _friendIds = friendIds;
          _incomingRequests = incomingRequests;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('멤버 목록 로드 실패: $e');

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _invite() async {
    // 혼자 여행 방에서는 다른 멤버를 추가할 수 없음
    if (_isSolo) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('혼자 여행'),
          content: const Text(
            '혼자 여행으로 설정된 방에는\n'
            '다른 멤버를 추가할 수 없습니다.\n\n'
            '여러 명이 함께 여행하려면 새로운 방을 만들어 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    final friends = await _repo.getFriends();
    final memberIds = _members.map((e) => e.userId).toSet();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '친구에게 방 초대',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (friends.isEmpty)
              const ListTile(
                title: Text('초대할 수 있는 친구가 없습니다.'),
                subtitle: Text(
                  '먼저 프로필의 친구 관리에서 친구를 추가해 주세요.',
                ),
              ),
            ...friends.map((f) {
              final alreadyMember = memberIds.contains(f.id);

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: f.avatarUrl == null
                      ? null
                      : NetworkImage(f.avatarUrl!),
                  child: f.avatarUrl == null
                      ? Text(
                          f.nickname.isEmpty ? '?' : f.nickname[0],
                        )
                      : null,
                ),
                title: Text(f.nickname),
                subtitle: Text(
                  alreadyMember ? '이미 방 멤버입니다' : f.email,
                ),
                trailing: alreadyMember
                    ? const Text(
                        '참여 중',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : FilledButton(
                        onPressed: () async {
                          try {
                            await _repo.inviteFriendToRoom(
                              widget.room.id,
                              f.id,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text('방 초대를 보냈습니다.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('초대'),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showMemberProfile(RoomMember m) async {
    if (m.userId == _repo.currentUserId) return;

    final isFriend = _friendIds.contains(m.userId);
    final requestId = _incomingRequests[m.userId];

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: m.avatarUrl == null
                    ? null
                    : NetworkImage(m.avatarUrl!),
                child: m.avatarUrl == null
                    ? Text(
                        m.nickname.isEmpty ? '?' : m.nickname[0],
                        style: const TextStyle(fontSize: 24),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                m.nickname.isEmpty ? '프로필 미입력' : m.nickname,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (isFriend)
                const Text(
                  '이미 친구입니다.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                )
              else if (requestId != null)
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      const Text(
                        '나에게 친구 요청을 보냈습니다.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  await _repo.respondFriendRequest(
                                    requestId,
                                    false,
                                  );

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }

                                  _load();
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('$e'),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('거절'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                try {
                                  await _repo.respondFriendRequest(
                                    requestId,
                                    true,
                                  );

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('친구가 되었습니다.'),
                                      ),
                                    );
                                  }

                                  _load();
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('$e'),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('수락'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      try {
                        await _repo.sendFriendRequest(m.userId);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('친구 요청을 보냈습니다.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('친구 요청 보내기'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    color: AppColors.room,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '초대 코드',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.room.inviteCode ?? '-',
                    style: const TextStyle(
                      fontSize: 22,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: widget.room.inviteCode ?? '',
                        ),
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('복사했습니다.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('코드 복사'),
                  ),
                  if (_owner)
                    FilledButton.icon(
                      onPressed: _invite,
                      icon: const Icon(Icons.group_add),
                      label: const Text('친구 초대'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '멤버 ${_members.length}명',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          ..._members.map(
            (m) => Card(
              child: ListTile(
                onTap: () => _showMemberProfile(m),
                leading: CircleAvatar(
                  backgroundImage: m.avatarUrl == null
                      ? null
                      : NetworkImage(m.avatarUrl!),
                  child: m.avatarUrl == null
                      ? Text(
                          m.nickname.isEmpty ? '?' : m.nickname[0],
                        )
                      : null,
                ),
                title: Text(
                  m.nickname.isEmpty ? '프로필 미입력' : m.nickname,
                ),
                subtitle: Text(
                  m.role == MemberRole.owner ? '방장' : '멤버',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}