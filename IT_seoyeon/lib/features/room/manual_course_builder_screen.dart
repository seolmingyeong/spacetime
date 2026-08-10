import 'package:flutter/material.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/category_utils.dart';
import '../../widgets/place_search_sheet.dart';

/// 저장된 장소(PlaceItem) 중에서 골라 일자별로 순서를 직접 짜는 화면.
/// 저장에 성공하면 true를 반환하며 pop 된다.
///
/// 이 화면 안에서 바로 새 장소를 검색해서 추가할 수도 있다 (Supabase의
/// places 테이블에 즉시 저장되고, 그 자리에서 바로 해당 날짜에 배치된다).
/// 검색 결과가 없거나 사용자가 아무것도 고르지 않은 경우, 또는 어떤 날짜가
/// 비어있는 경우에는 그 근처의 놀거리(attraction)를 대신 추천해서 채워
/// 넣을 수 있다.
class ManualCourseBuilderScreen extends StatefulWidget {
  final String roomId;
  final List<PlaceItem> places;
  const ManualCourseBuilderScreen({super.key, required this.roomId, required this.places});

  @override
  State<ManualCourseBuilderScreen> createState() => _ManualCourseBuilderScreenState();
}

class _ManualCourseBuilderScreenState extends State<ManualCourseBuilderScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController(text: '직접 만든 코스');
  TabController? _tabs;
  int _tripDays = 1;
  bool _isLoading = true;
  bool _isSaving = false;

  // 화면 안에서 새로 검색해 추가한 장소가 바로 반영되도록, widget.places를
  // 그대로 쓰지 않고 로컬 상태로 복사해서 들고 있는다.
  late List<PlaceItem> _places;

  // dayNumber(1-base) -> ordered list of place ids
  late Map<int, List<String>> _dayStops;
  // placeId -> 식사로 표시할지
  final Set<String> _mealPlaceIds = {};
  // 자동 채우기 진행 중인 day 번호들 (버튼 로딩 표시용)
  final Set<int> _autoFillingDays = {};

  @override
  void initState() {
    super.initState();
    _places = List<PlaceItem>.from(widget.places);
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    try {
      final room = await SupabaseRepository().getRoom(widget.roomId);
      _tripDays = room.tripDays.clamp(1, 30);
    } catch (_) {
      _tripDays = 1;
    }
    _dayStops = {for (var d = 1; d <= _tripDays; d++) d: <String>[]};
    _tabs = TabController(length: _tripDays, vsync: this);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Set<String> get _usedPlaceIds => _dayStops.values.expand((e) => e).toSet();

  void _addToDay(int day, PlaceItem place) {
    setState(() => _dayStops[day]!.add(place.id));
  }

  void _removeFromDay(int day, String placeId) {
    setState(() {
      _dayStops[day]!.remove(placeId);
      _mealPlaceIds.remove(placeId);
    });
  }

  void _reorder(int day, int oldIndex, int newIndex) {
    setState(() {
      final list = _dayStops[day]!;
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
  }

  Future<void> _pickPlace(int day) async {
    final remaining = _places.where((p) => !_usedPlaceIds.contains(p.id)).toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추가할 수 있는 장소가 없습니다. 새로 검색해서 추가해보세요.')));
      return;
    }
    final picked = await showModalBottomSheet<PlaceItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlacePickerSheet(places: remaining),
    );
    if (picked != null) _addToDay(day, picked);
  }

  /// 방 전체 장소들의 평균 좌표. 근처 놀거리를 추천받을 때 기준점으로 쓴다.
  List<double> _anchorLatLng() {
    if (_places.isEmpty) return const [37.5665, 126.9780]; // 서울 시청 (fallback)
    final avgLat = _places.map((p) => p.lat).reduce((a, b) => a + b) / _places.length;
    final avgLng = _places.map((p) => p.lng).reduce((a, b) => a + b) / _places.length;
    return [avgLat, avgLng];
  }

  /// 새 장소를 Supabase에 저장하고, 성공하면 로컬 장소 목록과 해당 날짜에 바로 반영한다.
  Future<void> _persistAndAddNewPlace(
    int day, {
    required String name,
    required String address,
    required double lat,
    required double lng,
    String? category,
  }) async {
    try {
      final saved = await SupabaseRepository().addPlace(
        widget.roomId,
        PlaceItem(id: '', name: name, address: address, lat: lat, lng: lng, category: category),
      );
      if (!mounted) return;
      setState(() {
        _places = [..._places, saved];
        _dayStops[day]!.add(saved.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${saved.name}"을(를) 장소 목록에 추가했습니다.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('장소 추가 실패: $e')));
      }
    }
  }

  /// 하루에 채워두고 싶은 목표 장소 수. 이미 이만큼 있으면 자동 채우기는
  /// 동작하지 않고, 부족한 만큼만 채운다.
  static const int _targetStopsPerDay = 5;

  /// 하루에 최소 보장하고 싶은 식사 횟수. 자동 채우기를 누르면 이 숫자에
  /// 모자란 만큼 음식점을 우선 채우고 식사로 표시한다.
  static const int _targetMealsPerDay = 2;

  /// 근처 추천 목록을 가져와서, 이미 쓴 장소는 제외하고 [preferredCategory]를
  /// 우선순위로 정렬해서 반환한다. 기본값은 놀거리(attraction).
  Future<List<PlaceSuggestion>> _fetchUnusedNearbySuggestions({String preferredCategory = 'attraction'}) async {
    final anchor = _anchorLatLng();
    final suggestions = await SupabaseRepository().getNearbyPlaceRecommendations(
      lat: anchor[0],
      lng: anchor[1],
    );
    final usedKeys = _places
        .where((p) => _usedPlaceIds.contains(p.id))
        .map((p) => '${p.name}_${p.lat}_${p.lng}')
        .toSet();
    final unused = suggestions.where((s) => !usedKeys.contains('${s.name}_${s.lat}_${s.lng}')).toList();
    unused.sort((a, b) {
      final aMatch = a.category == preferredCategory ? 0 : 1;
      final bMatch = b.category == preferredCategory ? 0 : 1;
      if (aMatch != bMatch) return aMatch - bMatch;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    return unused;
  }

  /// 근처 추천 장소를 최대 [count]개까지 순서대로 저장하며 그 날짜에 추가한다.
  /// 실제로 몇 개나 추가됐는지 반환한다 (근처에 추천할 곳이 부족하면 count보다 적을 수 있다).
  Future<int> _addNearbySuggestions(int day, List<PlaceSuggestion> candidates, int count) async {
    var added = 0;
    for (final s in candidates) {
      if (added >= count) break;
      await _persistAndAddNewPlace(day, name: s.name, address: s.address, lat: s.lat, lng: s.lng, category: s.category);
      added++;
    }
    return added;
  }

  /// 이미 채워진 개수를 보고, 목표(_targetStopsPerDay)에 모자란 만큼 근처
  /// 놀거리로 채운다. 식사(_targetMealsPerDay)가 모자라면 스탑 수 목표를
  /// 넘어서라도 부족한 끼니만큼은 항상 먼저 채운다.
  Future<void> _autoFillDay(int day) async {
    final current = _dayStops[day]!.length;
    final currentMeals = _dayStops[day]!.where(_mealPlaceIds.contains).length;
    final stopsNeeded = (_targetStopsPerDay - current).clamp(0, _targetStopsPerDay);
    final mealsNeeded = (_targetMealsPerDay - currentMeals).clamp(0, _targetMealsPerDay);

    if (stopsNeeded <= 0 && mealsNeeded <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이 날은 이미 ${current}곳(식사 $currentMeals끼)이 있어서 충분해요.')),
      );
      return;
    }

    setState(() => _autoFillingDays.add(day));
    try {
      var addedTotal = 0;

      // 1) 부족한 식사부터 채운다. 스탑 수가 이미 목표치여도 식사는 예외로 채운다.
      var mealsAdded = 0;
      if (mealsNeeded > 0) {
        final mealCandidates = await _fetchUnusedNearbySuggestions(preferredCategory: 'restaurant');
        final restaurants = mealCandidates.where((s) => s.category == 'restaurant').toList();
        for (final meal in restaurants) {
          if (mealsAdded >= mealsNeeded) break;
          final beforeLen = _dayStops[day]!.length;
          await _persistAndAddNewPlace(day, name: meal.name, address: meal.address, lat: meal.lat, lng: meal.lng, category: meal.category);
          // _persistAndAddNewPlace는 실패 시 내부에서 스낵바만 띄우고 조용히
          // 끝나므로, 실제로 추가됐는지 길이 변화로 확인한 뒤에만 식사로 표시한다.
          if (_dayStops[day]!.length > beforeLen) {
            final addedId = _dayStops[day]!.last;
            setState(() => _mealPlaceIds.add(addedId));
            mealsAdded++;
          }
        }
        addedTotal += mealsAdded;
      }

      // 2) 남은 자리는 놀거리로 채운다. 식사를 채우느라 이미 목표 스탑 수를
      // 넘겼을 수 있으니, 그만큼 놀거리 자리는 줄어든다.
      final attractionsNeeded = (stopsNeeded - mealsAdded).clamp(0, _targetStopsPerDay);
      if (attractionsNeeded > 0) {
        final candidates = await _fetchUnusedNearbySuggestions(preferredCategory: 'attraction');
        if (candidates.isEmpty && addedTotal == 0) throw '추천할 근처 장소를 찾지 못했습니다.';
        addedTotal += await _addNearbySuggestions(day, candidates, attractionsNeeded);
      }

      final totalWanted = mealsNeeded + attractionsNeeded;
      if (mounted && addedTotal < totalWanted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${addedTotal}곳 추가했어요 (근처에 추천할 곳이 그만큼밖에 없어요).')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('식사 포함해서 채워 넣었어요. 순서는 드래그로 조정할 수 있어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('자동 채우기 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _autoFillingDays.remove(day));
    }
  }

  /// 검색 결과가 없거나 사용자가 아무것도 선택하지 않고 검색창을 닫은 경우,
  /// 근처 놀거리로 대신 1곳을 채워 넣을지 물어본다. (목표 개수와 무관하게
  /// 방금 검색을 시도한 자리 하나만 채운다.)
  Future<void> _offerNearbyFallback(int day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('원하는 장소를 못 찾으셨나요?'),
        content: const Text('정확한 장소가 애매하거나 검색 결과가 없는 경우, 이 날 근처의 놀거리를 대신 추천해서 추가해드릴 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('괜찮아요')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('근처 놀거리 추천받기')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _autoFillingDays.add(day));
    try {
      final candidates = await _fetchUnusedNearbySuggestions();
      if (candidates.isEmpty) throw '추천할 근처 장소를 찾지 못했습니다.';
      await _addNearbySuggestions(day, candidates, 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('추천 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _autoFillingDays.remove(day));
    }
  }

  /// 새 장소를 검색해서 바로 그 날짜에 추가한다. 검색 결과가 없거나
  /// 사용자가 아무것도 고르지 않고 닫으면 근처 놀거리 추천을 제안한다.
  Future<void> _searchAndAddNewPlace(int day) async {
    bool selected = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceSearchSheet(
        roomId: widget.roomId,
        onPlaceSelected: (name, address, lat, lng, category) async {
          selected = true;
          await _persistAndAddNewPlace(day, name: name, address: address, lat: lat, lng: lng, category: category);
        },
      ),
    );
    if (!selected && mounted) {
      await _offerNearbyFallback(day);
    }
  }

  Future<void> _save() async {
    final totalStops = _dayStops.values.fold<int>(0, (a, b) => a + b.length);
    if (totalStops == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('최소 한 곳 이상 장소를 추가해주세요.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final days = <CourseDay>[
        for (var d = 1; d <= _tripDays; d++)
          if (_dayStops[d]!.isNotEmpty)
            CourseDay(
              dayNumber: d,
              stops: [
                for (var i = 0; i < _dayStops[d]!.length; i++)
                  CourseStop(
                    placeId: _dayStops[d]![i],
                    order: i,
                    isMeal: _mealPlaceIds.contains(_dayStops[d]![i]),
                  ),
              ],
            ),
      ];
      final course = CourseItem(
        id: '',
        name: _nameController.text.trim().isEmpty ? '직접 만든 코스' : _nameController.text.trim(),
        days: days,
      );
      await SupabaseRepository().addCourse(widget.roomId, course);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final placesById = {for (final p in _places) p.id: p};

    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 직접 만들기'),
        bottom: _tripDays > 1
            ? TabBar(controller: _tabs, isScrollable: true, tabs: [for (var d = 1; d <= _tripDays; d++) Tab(text: '$d일차')])
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '코스 이름', border: OutlineInputBorder()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (var d = 1; d <= _tripDays; d++) _buildDayView(d, placesById),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_isSaving ? '저장 중...' : '코스 저장'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
        ),
      ),
    );
  }

  Widget _buildDayView(int day, Map<String, PlaceItem> placesById) {
    final stopIds = _dayStops[day]!;
    final isAutoFilling = _autoFillingDays.contains(day);
    final mealCount = stopIds.where(_mealPlaceIds.contains).length;
    return Column(
      children: [
        if (stopIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.restaurant, size: 14, color: mealCount < _targetMealsPerDay ? Colors.red[300] : Colors.orange),
                const SizedBox(width: 4),
                Text(
                  mealCount >= _targetMealsPerDay
                      ? '이 날 식사 $mealCount끼 표시됨'
                      : '이 날 식사 $mealCount끼 표시됨 (목표 $_targetMealsPerDay끼)',
                  style: TextStyle(fontSize: 12, color: mealCount < _targetMealsPerDay ? Colors.red[300] : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        Expanded(
          child: stopIds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text('아직 이 날에 추가된 장소가 없어요.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: stopIds.length,
                  onReorder: (o, n) => _reorder(day, o, n),
                  itemBuilder: (context, i) {
                    final placeId = stopIds[i];
                    final place = placesById[placeId];
                    final info = getCategoryInfo(place?.category);
                    final isMeal = _mealPlaceIds.contains(placeId);
                    return Card(
                      key: ValueKey('day${day}_$placeId'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: info.color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(info.icon, color: info.color, size: 18),
                        ),
                        title: Text(place?.name ?? '(삭제된 장소)', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${i + 1}번째', style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '식사로 표시',
                              icon: Icon(Icons.restaurant, size: 20, color: isMeal ? Colors.orange : Colors.grey[300]),
                              onPressed: () => setState(() {
                                if (isMeal) {
                                  _mealPlaceIds.remove(placeId);
                                } else {
                                  _mealPlaceIds.add(placeId);
                                }
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => _removeFromDay(day, placeId),
                            ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPlace(day),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('저장된 장소에서 선택'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _searchAndAddNewPlace(day),
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text('새 장소 검색'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: isAutoFilling ? null : () => _autoFillDay(day),
                  icon: isAutoFilling
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    isAutoFilling
                        ? '추천 받는 중...'
                        : stopIds.length >= _targetStopsPerDay
                            ? 'AI로 채우기 (이미 충분해요)'
                            : 'AI로 채우기 (${stopIds.length}/$_targetStopsPerDay곳)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlacePickerSheet extends StatelessWidget {
  final List<PlaceItem> places;
  const _PlacePickerSheet({required this.places});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('추가할 장소 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: places.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final place = places[i];
                final info = getCategoryInfo(place.category);
                return ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: info.color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(info.icon, color: info.color, size: 18),
                  ),
                  title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}