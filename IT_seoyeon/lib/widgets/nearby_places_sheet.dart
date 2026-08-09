import 'package:flutter/material.dart';
import '../core/supabase_repository.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'category_utils.dart';

/// "만나기 좋은 동네 추천"에서 동네 하나를 탭했을 때 뜨는 바텀시트.
/// 그 동네 좌표 기준으로 실제 음식점/카페/놀거리를 보여주고, "추가하기"를
/// 누르면 바로 방의 장소 목록(places)에 저장된다.
class NearbyPlacesSheet extends StatefulWidget {
  final String roomId;
  final MidpointRecommendation region;
  final Set<String> alreadyAddedNames;
  const NearbyPlacesSheet({
    super.key,
    required this.roomId,
    required this.region,
    this.alreadyAddedNames = const {},
  });

  @override
  State<NearbyPlacesSheet> createState() => _NearbyPlacesSheetState();
}

class _NearbyPlacesSheetState extends State<NearbyPlacesSheet> {
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _addingKeys = {};
  final Set<String> _addedKeys = {};

  @override
  void initState() {
    super.initState();
    _addedKeys.addAll(widget.alreadyAddedNames);
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await SupabaseRepository().getNearbyPlaceRecommendations(
        lat: widget.region.lat,
        lng: widget.region.lng,
      );
      if (mounted) setState(() { _suggestions = result; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  String _keyOf(PlaceSuggestion s) => '${s.name}_${s.lat}_${s.lng}';

  Future<void> _add(PlaceSuggestion s) async {
    final key = _keyOf(s);
    setState(() => _addingKeys.add(key));
    try {
      final place = PlaceItem(
        id: '',
        name: s.name,
        address: s.address,
        lat: s.lat,
        lng: s.lng,
        category: s.category,
      );
      await SupabaseRepository().addPlace(widget.roomId, place);
      if (mounted) {
        setState(() { _addingKeys.remove(key); _addedKeys.add(key); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${s.name}"을(를) 장소에 추가했습니다.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingKeys.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('추가 실패: $e')));
      }
    }
  }

  Map<String, List<PlaceSuggestion>> get _grouped {
    final map = <String, List<PlaceSuggestion>>{'restaurant': [], 'cafe': [], 'attraction': []};
    for (final s in _suggestions) {
      map.putIfAbsent(s.category, () => []).add(s);
    }
    return map;
  }

  String _sectionLabel(String category) {
    switch (category) {
      case 'restaurant': return '음식점';
      case 'cafe': return '카페';
      case 'attraction': return '놀거리';
      default: return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.region.regionName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('이 동네 주변 장소를 추천해드려요. 마음에 들면 추가해보세요.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                    : _suggestions.isEmpty
                        ? const Center(child: Text('추천할 장소를 찾지 못했습니다.', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              for (final entry in _grouped.entries)
                                if (entry.value.isNotEmpty) _buildSection(_sectionLabel(entry.key), entry.value),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String label, List<PlaceSuggestion> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...items.map((s) => _buildRow(s)),
        ],
      ),
    );
  }

  Widget _buildRow(PlaceSuggestion s) {
    final info = getCategoryInfo(s.category);
    final key = _keyOf(s);
    final isAdding = _addingKeys.contains(key);
    final isAdded = _addedKeys.contains(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: info.color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(info.icon, color: info.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${s.address} · ${(s.distanceMeters / 1000).toStringAsFixed(1)}km',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: isAdded
                ? const Icon(Icons.check_circle, color: Colors.green)
                : ElevatedButton(
                    onPressed: isAdding ? null : () => _add(s),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.room.withOpacity(0.1),
                      foregroundColor: AppColors.room,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: isAdding
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('추가', style: TextStyle(fontSize: 12)),
                  ),
          ),
        ],
      ),
    );
  }
}
