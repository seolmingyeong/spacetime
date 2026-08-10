import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

import 'record_create_screen.dart';
import 'record_detail_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => RecordScreenState();
}

class RecordScreenState extends State<RecordScreen> {
  List<RecordAlbum> _allAlbums = [];
  List<RecordAlbum> _myAlbums = [];

  String? _selectedRoomId;
  List<TravelRoom> _rooms = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final repo = SupabaseRepository();

      final rooms = await repo.getRooms();

      debugPrint('rooms: $rooms.length');

      final allAlbums = await repo.getAlbums();
      final myAlbums = await repo.getMyAlbums();

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _allAlbums = allAlbums;
        _myAlbums = myAlbums;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '기록을 불러오지 못했습니다.\n$error',
          ),
        ),
      );
    }
  }

  /// 상세 화면에서 돌아온 결과를 처리한다.
  /// - 삭제: 목록에서 즉시 제거 (네트워크 왕복 없이).
  /// - 수정/좋아요: 그 앨범 하나만 다시 불러와 목록 안의 항목을 즉시 교체.
  ///   (좋아요는 상세 화면에서 이미 최신 개수를 알고 있지만, 모델 구조를
  ///   그대로 두기 위해 수정 때와 같은 방식으로 단건 재조회한다.)
  /// - 그 외(알 수 없는 값): 아무것도 하지 않는다.
  Future<void> _handleDetailResult(Object? result) async {
    if (result is Map && result['action'] == 'deleted') {
      final id = result['id'];
      if (!mounted) return;
      setState(() {
        _allAlbums.removeWhere((a) => a.id == id);
        _myAlbums.removeWhere((a) => a.id == id);
      });
      return;
    }

    if (result is Map &&
        (result['action'] == 'updated' || result['action'] == 'liked')) {
      final id = result['id'] as String;
      try {
        final fresh = await SupabaseRepository().getAlbum(id);
        if (!mounted) return;
        setState(() {
          final ai = _allAlbums.indexWhere((a) => a.id == id);
          if (ai != -1) _allAlbums[ai] = fresh;
          final mi = _myAlbums.indexWhere((a) => a.id == id);
          if (mi != -1) _myAlbums[mi] = fresh;
        });
      } catch (_) {
        // 단건 갱신에 실패하면 전체를 다시 불러온다.
        await reload();
      }
      return;
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RecordCreateScreen(),
      ),
    );

    if (created == true) {
      reload();
    }
  }

  String _visibility(RecordVisibility value) {
    switch (value) {
      case RecordVisibility.private:
        return '비공개';
      case RecordVisibility.friends:
        return '친구 공개';
      case RecordVisibility.public:
        return '전체 공개';
    }
  }

  @override
  Widget build(BuildContext context) {    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('날짜별 기록'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '전체 기록'),
              Tab(text: '내 기록'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.record,
          onPressed: _create,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('기록 만들기'),
        ),
        body: _loading
    ? const Center(
        child: CircularProgressIndicator(),
      )
    : Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _selectedRoomId == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedRoomId = null;
                    });
                  },
                ),
                const SizedBox(width: 8),

                ..._rooms.map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(room.name),
                      selected: _selectedRoomId == room.id,
                      onSelected: (_) {
                        setState(() {
                          _selectedRoomId = room.id;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [
                _albumList(_allAlbums),
                _albumList(_myAlbums),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  } 

  Widget _albumList(List<RecordAlbum> albums) {
    final filteredAlbums = _selectedRoomId == null
        ? albums
        : albums.where((album) => album.roomId == _selectedRoomId).toList();
    if (filteredAlbums.isEmpty) {
      final message = _selectedRoomId == null
          ? '아직 기록이 없습니다.'
          : '선택한 방에 기록이 없습니다.';
          
      return ListView(
        children: const [
          SizedBox(height: 180),
          Icon(
            Icons.photo_album_outlined,
            size: 70,
            color: AppColors.textSecondary,
          ),
          Center(
            child: Text(
              '아직 날짜별 기록이 없습니다.',
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAlbums.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
                    itemBuilder: (context, index) {
          final album = filteredAlbums[index];

          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RecordDetailScreen(album: album),
                  ),
                );
                await _handleDetailResult(result);
              },
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (album.coverUrl != null)
                    Image.network(
                      album.coverUrl!,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => const SizedBox(
                        height: 80,
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'yyyy.MM.dd',
                          ).format(album.recordDate),
                          style: const TextStyle(
                            color: AppColors.record,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          album.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: album.ownerAvatar != null
                                ? NetworkImage(album.ownerAvatar!)
                                : null,
                              child: album.ownerAvatar == null
                                ? const Icon(Icons.person, size: 12)
                                : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              album.ownerName ?? '알 수 없음',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            )
                          ]
                        ),

                        Text(
                          '${album.photoCount}장 · ${_visibility(album.visibility)} · '
                          '좋아요 ${album.likeCount} · 댓글 ${album.commentCount}',
                          style: const TextStyle(
                            color:
                                AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}