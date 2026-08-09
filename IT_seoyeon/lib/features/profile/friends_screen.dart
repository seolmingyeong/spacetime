import 'package:flutter/material.dart';
import '../../core/supabase_repository.dart';
import '../../models/models.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _email = TextEditingController();
  List<UserProfile> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  UserProfile? _found;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _load() async {
    final values = await Future.wait([
      SupabaseRepository().getFriends(),
      SupabaseRepository().getFriendRequests(),
    ]);
    if (mounted) {
      setState(() {
        _friends = values[0] as List<UserProfile>;
        _requests = values[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    final profile = await SupabaseRepository().findUserByEmail(_email.text.trim());
    if (!mounted) return;
    setState(() => _found = profile);
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해당 이메일의 사용자를 찾지 못했습니다.')),
      );
    }
  }

  Widget _avatar(UserProfile profile) {
    return CircleAvatar(
      backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
      child: profile.avatarUrl == null
          ? Text(profile.nickname.isEmpty ? '?' : profile.nickname[0])
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구 관리')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: '친구의 Google 이메일',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                  ),
                ),
                if (_found != null)
                  Card(
                    child: ListTile(
                      leading: _avatar(_found!),
                      title: Text(_found!.nickname),
                      subtitle: Text(_found!.email),
                      trailing: FilledButton(
                        onPressed: () async {
                          await SupabaseRepository().sendFriendRequest(_found!.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('친구 요청을 보냈습니다.')),
                            );
                          }
                        },
                        child: const Text('요청'),
                      ),
                    ),
                  ),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('받은 요청', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._requests.map(
                    (request) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: request['avatar_url'] == null
                              ? null
                              : NetworkImage(request['avatar_url']),
                        ),
                        title: Text(request['nickname'] ?? ''),
                        subtitle: Text(request['email'] ?? ''),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await SupabaseRepository().respondFriendRequest(request['id'].toString(), false);
                                _load();
                              },
                              icon: const Icon(Icons.close),
                            ),
                            IconButton(
                              onPressed: () async {
                                await SupabaseRepository().respondFriendRequest(request['id'].toString(), true);
                                _load();
                              },
                              icon: const Icon(Icons.check, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text('친구 ${_friends.length}명', style: const TextStyle(fontWeight: FontWeight.bold)),
                ..._friends.map(
                  (friend) => Card(
                    child: ListTile(
                      leading: _avatar(friend),
                      title: Text(friend.nickname),
                      subtitle: Text(friend.email),
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'remove', child: Text('친구 삭제')),
                        ],
                        onSelected: (value) async {
                          if (value == 'remove') {
                            await SupabaseRepository().removeFriend(friend.id);
                            _load();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
