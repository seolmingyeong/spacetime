import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/supabase_repository.dart';
import '../../../core/theme.dart';
import '../../../models/models.dart';
import '../departure_info_screen.dart';

class ScheduleTabView extends StatefulWidget {
  final String roomId;
  const ScheduleTabView({super.key, required this.roomId});

  @override
  State<ScheduleTabView> createState() => _ScheduleTabViewState();
}

class _ScheduleTabViewState extends State<ScheduleTabView> {
  final _repo = SupabaseRepository();
  TravelRoom? _room;
  List<DateAvailability> _availability = [];
  List<ScheduleCandidate> _candidates = [];
  Set<DateTime> _selected = {};
  bool _loading = true;
  bool _saving = false;

  // approval/voting 단계에서도 날짜를 다시 고를 수 있게 하는 편집 모드.
  bool _editingDates = false;

  DateTime _focused = DateTime.now();
  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _repo.getRoom(widget.roomId),
        _repo.getAllAvailabilities(widget.roomId),
        _repo.getScheduleCandidates(widget.roomId),
      ]);
      if (mounted) {
        setState(() {
          _room = values[0] as TravelRoom;
          _availability = values[1] as List<DateAvailability>;
          _candidates = values[2] as List<ScheduleCandidate>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('일정 로드 실패: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repo.saveAvailability(widget.roomId, _selected.toList());
      if (mounted) setState(() => _editingDates = false);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('제출 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// approval/voting 단계에서 "다시 정하기"를 누르면 호출된다.
  /// 내가 이전에 제출했던 날짜를 캘린더에 미리 채워서 보여준다.
  void _startEditingDates() {
    DateAvailability? mine;
    for (final a in _availability) {
      if (a.userId == _repo.currentUserId) {
        mine = a;
        break;
      }
    }
    setState(() {
      _selected = mine != null ? mine.availableDates.map(_day).toSet() : {};
      _editingDates = true;
    });
  }

  Future<void> _approve(ScheduleCandidate c, bool yes) async {
    await _repo.approveCandidate(widget.roomId, c.id, yes);
    await _load();
  }

  Future<void> _vote(ScheduleCandidate c) async {
    await _repo.voteCandidate(widget.roomId, c.id);
    await _load();
  }

  String _range(ScheduleCandidate c) {
    final start = DateFormat('M월 d일').format(c.startDate);
    if (_day(c.startDate) == _day(c.endDate)) return start;
    final end = DateFormat('M월 d일').format(c.endDate);
    return '$start ~ $end';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_room == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('일정 정보를 불러오지 못했습니다.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final r = _room!;

    if (_editingDates) return _editingPicker(r);
    if (r.isScheduleFinalized) return _finalized(r);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.schedule.withOpacity(.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.tripDurationLabel} 여행',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text('${_availability.length}/${r.memberCount}명이 가능한 날짜를 제출했습니다.',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: r.memberCount == 0 ? 0 : _availability.length / r.memberCount),
                ],
              ),
            ),
          ),
          if (r.schedulePhase == 'collecting') ...[
            _availabilityPicker(r),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? '제출 중...' : '가능한 날짜 제출'),
            ),
          ],
          if (r.schedulePhase == 'approval' && _candidates.isNotEmpty)
            _approvalCard(_candidates.first),
          if (r.schedulePhase == 'voting') ...[
            _title('공동 1등 날짜 후보'),
            const Text('가장 원하는 날짜 하나를 선택해 주세요. 확정 전까지는 다시 선택할 수 있습니다.'),
            const SizedBox(height: 10),
            ..._candidates.map(_voteCard),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _startEditingDates,
              icon: const Icon(Icons.edit_calendar),
              label: const Text('내 가능한 날짜 다시 정하기'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _calendarCard() => Card(
        child: TableCalendar(
          locale: 'ko_KR',
          firstDay: DateTime.now(),
          lastDay: DateTime.now().add(const Duration(days: 730)),
          focusedDay: _focused,
          selectedDayPredicate: (d) => _selected.contains(_day(d)),
          onDaySelected: (d, f) => setState(() {
            _focused = f;
            final x = _day(d);
            _selected.contains(x) ? _selected.remove(x) : _selected.add(x);
          }),
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          calendarStyle: const CalendarStyle(
            selectedDecoration: BoxDecoration(color: AppColors.schedule, shape: BoxShape.circle),
          ),
        ),
      );

  Widget _availabilityPicker(TravelRoom r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _title('내가 가능한 날짜'),
          const Text('가능한 날짜를 모두 선택하세요. 모든 멤버가 제출하면 후보가 자동 계산됩니다.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _calendarCard(),
        ],
      );

  /// approval/voting 단계에서 "다시 정하기"를 눌렀을 때 보여주는 화면.
  /// 방 전체의 schedule_phase는 건드리지 않고, 내 날짜만 다시 제출한다.
  /// 제출하면 서버에서 후보가 재계산되고(겹치는 후보는 투표가 유지됨), 다른 멤버에게 알림이 간다.
  Widget _editingPicker(TravelRoom r) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _title('가능한 날짜 다시 선택')),
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _editingDates = false),
                  child: const Text('취소'),
                ),
              ],
            ),
            const Text(
              '날짜를 바꾸면 후보가 다시 계산되고, 이전 후보와 겹치는 날짜는 그대로 유지돼요. '
              '다른 멤버에게는 후보가 변경됐다는 알림이 갑니다.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            _calendarCard(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? '제출 중...' : '다시 제출'),
            ),
          ],
        ),
      );

  Widget _approvalCard(ScheduleCandidate c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title('최적 날짜 후보'),
              const SizedBox(height: 8),
              Text(_range(c), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${c.availableMemberCount}명이 전체 기간에 참여할 수 있습니다.'),
              const SizedBox(height: 16),
              const Text('모든 멤버가 동의하면 일정이 확정되며 이후 변경할 수 없습니다.'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _startEditingDates,
                      child: const Text('다시 정하기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: c.myApproval == true ? null : () => _approve(c, true),
                      child: Text(c.myApproval == true ? '동의 완료' : '동의하기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _voteCard(ScheduleCandidate c) => Card(
        child: ListTile(
          title: Text(_range(c)),
          subtitle: Text('${c.availableMemberCount}명 가능 · ${c.voteCount}표'),
          trailing: c.hasMyVote
              ? const Chip(label: Text('내 선택'), avatar: Icon(Icons.check, size: 16))
              : OutlinedButton(onPressed: () => _vote(c), child: const Text('선택')),
        ),
      );

  Widget _finalized(TravelRoom r) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.green[600],
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('여행 일정이 확정되었습니다',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    _finalizedRangeText(r),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text('확정된 날짜는 변경할 수 없습니다.', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.my_location, color: AppColors.schedule),
              title: const Text('내 출발 정보'),
              subtitle: const Text('일정 확정 후 출발 위치와 이동수단을 입력해 주세요.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DepartureInfoScreen(roomId: widget.roomId)),
              ),
            ),
          ),
        ],
      );

  String _finalizedRangeText(TravelRoom r) {
    final start = r.startDate!;
    final end = r.endDate ?? r.startDate!;
    final startText = DateFormat('yyyy.MM.dd').format(start);
    if (_day(start) == _day(end)) return startText;
    final endText = DateFormat('yyyy.MM.dd').format(end);
    return '$startText ~ $endText';
  }

  Widget _title(String s) => Text(s, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}