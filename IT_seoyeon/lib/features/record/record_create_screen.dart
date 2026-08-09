import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// Holds the in-progress form state for a single place/entry within the
/// album being created.
class _EntryDraft {
  final TextEditingController place;
  final TextEditingController address;
  final TextEditingController note;
  TimeOfDay? time;
  final List<XFile> photos;

  _EntryDraft({
    String place = '',
    String address = '',
    String note = '',
    this.time,
    List<XFile>? photos,
  })  : place = TextEditingController(text: place),
        address = TextEditingController(text: address),
        note = TextEditingController(text: note),
        photos = photos ?? [];

  Map<String, dynamic> json() => {
        'place': place.text,
        'address': address.text,
        'note': note.text,
        'time': time == null ? null : '${time!.hour}:${time!.minute}',
        'photos': photos.map((e) => e.path).toList(),
      };

  void dispose() {
    place.dispose();
    address.dispose();
    note.dispose();
  }
}

class RecordCreateScreen extends StatefulWidget {
  final String? roomId;
  final RecordAlbum? album;

  const RecordCreateScreen({super.key, this.roomId, this.album});

  @override
  State<RecordCreateScreen> createState() => _RecordCreateScreenState();
}

class _RecordCreateScreenState extends State<RecordCreateScreen> {
  static const _draftKey = 'record_album_draft';

  final _title = TextEditingController();
  final _picker = ImagePicker();

  DateTime _date = DateTime.now();
  RecordVisibility _visibility = RecordVisibility.private;
  String? _roomId;
  List<TravelRoom> _rooms = [];
  final List<_EntryDraft> _entries = [];

  bool _saving = false;
  // Set once the album has been saved successfully, so dispose() doesn't
  // re-write a draft for data that no longer needs to be recovered.
  bool _saved = false;

  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
    _load();
  }

  Future<void> _load() async {
    final rooms = await SupabaseRepository().getRooms();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);

    if (widget.album != null) {
        _title.text = widget.album!.title;
        _date = widget.album!.recordDate;
        _visibility = widget.album!.visibility;
        _roomId = widget.album!.roomId;

        final entries = await SupabaseRepository()
            .getAlbumEntries(widget.album!.id);

        _entries.clear();

        if (mounted) {
            setState(() {
              _rooms = rooms;
            });
        }

        for (final entry in entries) {
            TimeOfDay? time;
            
            if (entry.visitTime != null && entry.visitTime!.isNotEmpty) {
                final parts = entry.visitTime!.split(':');
                time = TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                );
            }

            _entries.add(
                _EntryDraft(
                place: entry.placeName,
                address: entry.address ?? '',
                note: entry.note ?? '',
                time: time,
                photos: [],
                ),
            );
        }

        // 서버에 등록된 장소가 하나도 없을 때만 빈 카드를 하나 보여줍니다.
        if (_entries.isEmpty) {
            _entries.add(_EntryDraft());
        }
        return;
    }

    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        _title.text = d['title'] ?? '';
        _date = DateTime.tryParse(d['date'] ?? '') ?? DateTime.now();
        _visibility = RecordVisibility.values.firstWhere(
          (e) => e.name == d['visibility'],
          orElse: () => RecordVisibility.private,
        );

        for (final x in d['entries'] ?? []) {
          TimeOfDay? t;
          if (x['time'] != null) {
            final parts = x['time'].split(':');
            t = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          _entries.add(_EntryDraft(
            place: x['place'] ?? '',
            address: x['address'] ?? '',
            note: x['note'] ?? '',
            time: t,
            photos: (x['photos'] as List? ?? []).map((v) => XFile(v)).toList(),
          ));
        }
      } catch (_) {
        // Corrupt or incompatible draft data — ignore and start fresh.
      }
    }

    if (_entries.isEmpty) _entries.add(_EntryDraft());
    if (mounted) setState(() => _rooms = rooms);
  }

  /// Persists the current form state so it can be restored later.
  /// Skipped while actively saving, or after a successful save, since
  /// there's nothing left to recover in either case.
  Future<void> _draft() async {
    if (_saving || _saved) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode({
        'title': _title.text,
        'date': _date.toIso8601String(),
        'visibility': _visibility.name,
        'entries': _entries.map((e) => e.json()).toList(),
      }),
    );
  }

  Future<void> _pickPhotos(_EntryDraft entry) async {
    final files = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (files.isNotEmpty) {
      setState(() => entry.photos.addAll(files.take(20 - entry.photos.length)));
    }
  }

  Future<void> _takePhoto(_EntryDraft entry) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file != null) setState(() => entry.photos.add(file));
  }

  Future<void> _save() async {
    debugPrint('Saving album=${widget.album?.id}');
    if (_saving) return;

    final missingTitle = _title.text.trim().isEmpty;
    final missingPlace = _entries.any((e) => e.place.text.trim().isEmpty);
    if (missingTitle || missingPlace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앨범 제목과 장소 이름을 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _total = _entries.fold(0, (sum, e) => sum + e.photos.length);
      _done = 0;
    });

    try {
      final repo = SupabaseRepository();
      
      RecordAlbum album;

      if (widget.album == null) {
        debugPrint('CREATE');
        album = await repo.createAlbum(
          date: _date,
          title: _title.text,
          visibility: _visibility,
          roomId: _roomId,
        );
      } else {
        debugPrint('UPDATE');
        await repo.updateAlbum(
          albumId: widget.album!.id,
          date: _date,
          title: _title.text,
          visibility: _visibility,
          roomId: _roomId,
        );

        album = widget.album!;

      }

      if (widget.album != null) {
        await repo.clearAlbumEntries(widget.album!.id);
      }

      var isCover = true;
      for (var i = 0; i < _entries.length; i++) {
        final entry = _entries[i];
        final entryId = await repo.addAlbumEntry(
          albumId: album.id,
          placeName: entry.place.text,
          address: entry.address.text.trim(),
          visitTime: entry.time == null
              ? null
              : '${entry.time!.hour.toString().padLeft(2, '0')}:'
                  '${entry.time!.minute.toString().padLeft(2, '0')}',
          note: entry.note.text.trim(),
          orderIndex: i,
        );

        for (var j = 0; j < entry.photos.length; j++) {
          final bytes = await entry.photos[j].readAsBytes();
          await repo.uploadRecordPhoto(
            albumId: album.id,
            entryId: entryId,
            bytes: bytes,
            orderIndex: j,
            isCover: isCover,
          );
          isCover = false;
          if (mounted) setState(() => _done++);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      _saved = true;

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '저장 실패: $e\n업로드된 항목은 보존되며 다시 시도할 수 있습니다.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _draft();
    _title.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  String _visibilityLabel(RecordVisibility v) => switch (v) {
        RecordVisibility.private => '비공개',
        RecordVisibility.friends => '친구 공개',
        RecordVisibility.public => '전체 공개',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.album == null ? '날짜별 기록 만들기' : '기록 수정'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
                widget.album == null ? '저장' : '수정'),
          ),
        ],
      ),
      body: _saving ? _buildUploadProgress() : _buildForm(),
    );
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('사진 업로드 중 $_done/$_total'),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: '기록 제목',
            hintText: '예: 서울 여름 나들이',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: Colors.white,
          leading: const Icon(Icons.calendar_today),
          title: const Text('기록 날짜'),
          subtitle: Text('${_date.year}.${_date.month}.${_date.day}'),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              initialDate: _date,
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        DropdownButtonFormField<RecordVisibility>(
          value: _visibility,
          decoration: const InputDecoration(labelText: '공개 범위'),
          items: RecordVisibility.values
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(_visibilityLabel(v)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _visibility = v!),
        ),
        if (_rooms.isNotEmpty)
          DropdownButtonFormField<String?>(
            value: _roomId,
            decoration: const InputDecoration(labelText: '연결할 여행 방 (선택)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('연결하지 않음')),
              ..._rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
            ],
            onChanged: (v) => setState(() => _roomId = v),
          ),
        const SizedBox(height: 18),
        for (final indexed in _entries.asMap().entries)
          _buildEntryCard(indexed.key, indexed.value),
        OutlinedButton.icon(
          onPressed: () => setState(() => _entries.add(_EntryDraft())),
          icon: const Icon(Icons.add_location_alt),
          label: const Text('장소 추가'),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildEntryCard(int index, _EntryDraft entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('장소 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_entries.length > 1)
                  IconButton(
                    onPressed: () => setState(() {
                      _entries.removeAt(index);
                      entry.dispose();
                    }),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            TextField(
              controller: entry.place,
              decoration: const InputDecoration(labelText: '장소 이름'),
            ),
            TextField(
              controller: entry.address,
              decoration: const InputDecoration(labelText: '주소 (선택)'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('방문 시간 (선택)'),
              subtitle: Text(entry.time?.format(context) ?? '시간 미정'),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: entry.time ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => entry.time = picked);
              },
            ),
            TextField(
              controller: entry.note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '사진과 함께 남길 코멘트'),
            ),
            const SizedBox(height: 10),
            if (entry.photos.isNotEmpty) _buildPhotoGrid(entry),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhotos(entry),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('여러 장 선택'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _takePhoto(entry),
                  icon: const Icon(Icons.camera_alt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(_EntryDraft entry) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entry.photos.asMap().entries.map((indexed) {
        final photo = indexed.value;
        return Stack(
          children: [
            FutureBuilder(
              future: photo.readAsBytes(),
              builder: (context, snapshot) => Container(
                width: 78,
                height: 78,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: snapshot.hasData ? Image.memory(snapshot.data!, fit: BoxFit.cover) : null,
              ),
            ),
            Positioned(
              right: 0,
              child: InkWell(
                onTap: () => setState(() => entry.photos.removeAt(indexed.key)),
                child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}