import 'package:flutter/material.dart';
import '../../../core/supabase_repository.dart';
import '../../../core/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/category_utils.dart';
import '../manual_course_builder_screen.dart';

class CourseTabView extends StatefulWidget {
  final String roomId;
  const CourseTabView({super.key, required this.roomId});

  @override
  State<CourseTabView> createState() => _CourseTabViewState();
}

class _CourseTabViewState extends State<CourseTabView> {
  List<CourseItem> _courses = [];
  List<PlaceItem> _places = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    final repo = SupabaseRepository();
    final results = await Future.wait([
      repo.getCourses(widget.roomId),
      repo.getPlaces(widget.roomId),
    ]);
    if (mounted) {
      setState(() {
        _courses = results[0] as List<CourseItem>;
        _places = results[1] as List<PlaceItem>;
        _isLoading = false;
      });
    }
  }

  Map<String, PlaceItem> get _placesById => {for (final p in _places) p.id: p};

  Future<void> _generateAiCourse() async {
    if (_places.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 코스를 짜려면 장소를 2곳 이상 추가해주세요.')),
      );
      return;
    }

    final mealsPerDay = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('하루 식사 횟수'),
        children: [1, 2, 3]
            .map((n) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, n),
                  child: Text(n == 1 ? '1회 (점심만)' : n == 2 ? '2회 (점심+저녁)' : '3회 (아침+점심+저녁)'),
                ))
            .toList(),
      ),
    );
    if (mealsPerDay == null) return;

    setState(() => _isGenerating = true);
    try {
      final repo = SupabaseRepository();
      final generated = await repo.generateOptimalCourse(widget.roomId, mealsPerDay: mealsPerDay);
      await repo.addCourse(widget.roomId, generated);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 추천 코스가 생성되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코스 생성 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _addManualCourse() async {
    if (_places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소 탭에서 먼저 장소를 추가해주세요.')),
      );
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualCourseBuilderScreen(roomId: widget.roomId, places: _places),
      ),
    );
    // 코스를 저장하지 않고 나왔더라도 화면 안에서 새 장소를 검색/추가했을 수
    // 있으므로, 코스 저장 여부와 무관하게 항상 다시 불러온다.
    if (mounted) _loadAll();
  }

  Future<void> _voteCourse(CourseItem course) async {
    // 낙관적 업데이트: 즉시 UI에 반영하고, 실패하면 되돌린다.
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index == -1) return;
    final wasVoted = course.hasMyVote;
    final optimistic = CourseItem(
      id: course.id,
      name: course.name,
      days: course.days,
      votes: wasVoted ? course.votes - 1 : course.votes + 1,
      isConfirmed: course.isConfirmed,
      hasMyVote: !wasVoted,
    );
    setState(() => _courses[index] = optimistic);
    try {
      await SupabaseRepository().voteCourse(course.id);
    } catch (e) {
      if (mounted) {
        setState(() => _courses[index] = course);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('투표 실패: $e')));
      }
    }
  }

  Future<void> _deleteCourse(CourseItem course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코스 삭제'),
        content: Text('\'${course.name}\' 코스를 삭제할까요?\n삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 낙관적 업데이트: 즉시 리스트에서 제거하고, 실패하면 되돌린다.
    final removedIndex = _courses.indexOf(course);
    setState(() => _courses.remove(course));
    try {
      await SupabaseRepository().deleteCourse(course.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코스가 삭제되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _courses.insert(removedIndex.clamp(0, _courses.length), course));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코스 삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: _courses.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  itemCount: _courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final course = _courses[i];
                    return _CourseCard(
                      course: course,
                      placesById: _placesById,
                      onDelete: () => _deleteCourse(course),
                      onVote: () => _voteCourse(course),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[400]!, Colors.blue[600]!]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('여행 동선을 계획해보세요', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateAiCourse,
                  icon: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_isGenerating ? '계산 중...' : 'AI 최적 경로 계산'),
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.blue[800]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _addManualCourse,
                  icon: const Icon(Icons.add_road),
                  label: const Text('경로 직접 추가'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('등록된 코스가 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
          const Text('AI 최적 경로를 계산하거나 직접 경로를 짜보세요.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseItem course;
  final Map<String, PlaceItem> placesById;
  final VoidCallback onDelete;
  final VoidCallback onVote;
  const _CourseCard({required this.course, required this.placesById, required this.onDelete, required this.onVote});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: course.isConfirmed ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(course.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                if (course.isConfirmed)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Chip(label: Text('확정 코스', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.blue),
                  ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: '코스 삭제',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (course.days.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('아직 배치된 장소가 없습니다.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              )
            else
              ...course.days.map((day) => _buildDaySection(day)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onVote,
                  style: TextButton.styleFrom(
                    foregroundColor: course.hasMyVote ? Colors.blue[700] : null,
                  ),
                  icon: Icon(course.hasMyVote ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined),
                  label: Text('투표 (${course.votes})')
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(CourseDay day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${day.dayNumber}일차', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
          ),
          for (var i = 0; i < day.stops.length; i++)
            _buildTimelineItem(day.stops[i], isFirst: i == 0, isLast: i == day.stops.length - 1),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(CourseStop stop, {bool isFirst = false, bool isLast = false}) {
    final place = placesById[stop.placeId];
    final name = place?.name ?? '(삭제된 장소)';
    final info = getCategoryInfo(place?.category);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: stop.isMeal ? Colors.orange : (isFirst ? Colors.blue : (isLast ? Colors.green : Colors.grey)),
                shape: BoxShape.circle
              ),
            ),
            if (!isLast) Container(width: 2, height: 28, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(info.icon, size: 14, color: info.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(name, style: TextStyle(color: isFirst || isLast ? Colors.black87 : Colors.grey[800], fontWeight: FontWeight.w500)),
                ),
                if (stop.arrivalTime != null)
                  Text(stop.arrivalTime!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (stop.isMeal) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.restaurant, size: 12, color: Colors.orange),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}