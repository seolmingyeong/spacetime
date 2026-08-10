import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'record_create_screen.dart';
import '../../widgets/photo_page_view.dart';

class RecordDetailScreen extends StatefulWidget {
  final RecordAlbum album;
  const RecordDetailScreen({super.key, required this.album});
  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  List<RecordEntry> _entries = [];
  bool _loading = true;
  int _likes = 0;
  int _commentsCount = 0;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.album.likeCount;
    _commentsCount = widget.album.commentCount;
    _liked = widget.album.isLiked;
    _load();
  }

  Future<void> _load() async {
    final entries = await SupabaseRepository().getAlbumEntries(widget.album.id);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('앨범과 모든 사진이 삭제되며 복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SupabaseRepository().deleteAlbum(widget.album.id);
        if (mounted) {
          Navigator.pop(context, {'action': 'deleted', 'id': widget.album.id});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.title),
        actions: [
          if (widget.album.ownerId == SupabaseRepository().currentUserId)
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordCreateScreen(
                      album: widget.album,
                      roomId: widget.album.roomId,
                    ),
                  ),
                );
                if (updated == true && mounted) {
                  Navigator.pop(context, {'action': 'updated', 'id': widget.album.id});
                }
              } else if (value == 'delete') {
                _delete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('수정'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('삭제'),
              ),
            ],
          ),
        ],
      
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  DateFormat('yyyy년 M월 d일').format(widget.album.recordDate),
                  style: const TextStyle(color: AppColors.record, fontWeight: FontWeight.bold),
                ),
                Text(widget.album.title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),

                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: widget.album.ownerAvatar != null 
                        ? NetworkImage(widget.album.ownerAvatar!) 
                        : null,
                      child: widget.album.ownerAvatar == null
                        ? const Icon(Icons.person, size: 14)
                        : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.album.ownerName ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),

                const SizedBox(height: 20),
                ..._entries.asMap().entries.map((pair) {
                  final number = pair.key + 1;
                  final entry = pair.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$number. ${entry.placeName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (entry.visitTime != null) Text(entry.visitTime!.substring(0, 5)),
                          if (entry.address != null) Text(entry.address!, style: const TextStyle(color: AppColors.textSecondary)),
                          if (entry.photos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            PhotoPageView(
                              urls: entry.photos.map((photo) => photo.url).toList(),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                          if (entry.note?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            Text(entry.note!, style: const TextStyle(height: 1.5)),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        final liked = await SupabaseRepository().toggleAlbumLike(
                          widget.album.id,
                          albumOwnerId: widget.album.ownerId,
                          albumTitle: widget.album.title,
                        );
                        if (mounted) {
                          setState(() {
                            _liked = liked;
                            _likes += liked ? 1 : -1;
                          });
                        }
                      },
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? Colors.red : null,
                      ),
                    ),
                    Text('$_likes'),
                    const SizedBox(width: 16),
                    IconButton(onPressed: _comments, icon: const Icon(Icons.comment_outlined)),
                    Text('$_commentsCount'),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _comments() async {
    final controller = TextEditingController();
    var items = await SupabaseRepository().getAlbumComments(widget.album.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('댓글', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView(
                    children: items.map((item) {
                      final isMine = item['user_id']?.toString() ==
                          SupabaseRepository().currentUserId;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundImage: item['profiles']?['avatar_url'] != null
                              ? NetworkImage(item['profiles']['avatar_url'])
                              : null,
                          child: item['profiles']?['avatar_url'] == null
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        title: Text(item['profiles']?['nickname'] ?? '알 수 없음'),
                        subtitle: Text(item['content'] ?? ''),


                        trailing: isMine
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () async {
                                  await SupabaseRepository()
                                      .deleteAlbumComment(item['id'].toString());
                                  items = await SupabaseRepository()
                                      .getAlbumComments(widget.album.id);
                                  setLocal(() {});
                                },
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: '댓글 입력'))),
                    IconButton(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        await SupabaseRepository().addAlbumComment(
                          widget.album.id,
                          controller.text.trim(),
                          albumOwnerId: widget.album.ownerId,
                          albumTitle: widget.album.title,
                        );
                        controller.clear();
                        items = await SupabaseRepository().getAlbumComments(widget.album.id);
                        setLocal(() {});
                      },
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (mounted) setState(() => _commentsCount = items.length);
  }

}