import 'package:flutter/material.dart';
import '../../../core/supabase_repository.dart';
import '../../../core/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/category_utils.dart';
import '../../../widgets/place_search_sheet.dart';
import '../../../widgets/nearby_places_sheet.dart';

class PlaceTabView extends StatefulWidget {
  final String roomId;

  const PlaceTabView({
    super.key,
    required this.roomId,
  });

  @override
  State<PlaceTabView> createState() => _PlaceTabViewState();
}

class _PlaceTabViewState extends State<PlaceTabView> {
  List<PlaceItem> _places = [];
  bool _isLoading = true;

  List<MidpointRecommendation> _midpoints = [];
  bool _midpointLoading = true;
  String? _midpointError;
  String _travelType = 'group';
  DepartureInfo? _departure;
  List<PlaceSuggestion> _soloRecommendations = [];
  bool _soloLoading = true;
  String? _soloError;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadRoomType();
  }

  Future<void> _loadPlaces() async {
    final places =
        await SupabaseRepository().getPlaces(widget.roomId);

    if (mounted) {
      setState(() {
        _places = places;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoomType() async {
    try {
      final room = await SupabaseRepository().getRoom(widget.roomId);
      if (!mounted) return;

      setState(() {
        _travelType = room.travelType;
      });

      if (_travelType == 'solo') {
        await _loadSoloRecommendations();
      } else {
        await _loadMidpoints();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _soloLoading = false;
          _midpointLoading = false;
          _soloError = '$e';
        });
      }
    }
  }

  Future<void> _loadMidpoints({
    bool forceRefresh = false,
  }) async {
    if (_travelType == 'solo') return;

    if (mounted) {
      setState(() {
        _midpointLoading = true;
        _midpointError = null;
      });
    }

    try {
      final result = await SupabaseRepository()
          .getMidpointRecommendations(
        widget.roomId,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _midpoints = result;
          _midpointLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _midpointError = '$e';
          _midpointLoading = false;
        });
      }
    }
  }

  Future<void> _loadSoloRecommendations() async {
    if (mounted) {
      setState(() {
        _soloLoading = true;
        _soloError = null;
      });
    }

    try {
      final departure =
          await SupabaseRepository().getDepartureInfo(widget.roomId);

      if (departure == null) {
        if (mounted) {
          setState(() {
            _departure = null;
            _soloRecommendations = [];
            _soloLoading = false;
            _soloError = '출발지를 먼저 입력해주세요.';
          });
        }
        return;
      }

      final recommendations =
          await SupabaseRepository().getNearbyPlaceRecommendations(
        lat: departure.lat,
        lng: departure.lng,
        radiusMeters: 1500,
      );

      if (mounted) {
        setState(() {
          _departure = departure;
          _soloRecommendations = recommendations;
          _soloLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _soloLoading = false;
          _soloError = '$e';
        });
      }
    }
  }

  Future<void> _addRecommendedPlace(PlaceSuggestion suggestion) async {
    final alreadyAdded = _places.any(
      (p) =>
          p.name == suggestion.name &&
          p.lat == suggestion.lat &&
          p.lng == suggestion.lng,
    );

    if (alreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 추가된 장소입니다.')),
      );
      return;
    }

    try {
      await SupabaseRepository().addPlace(
        widget.roomId,
        PlaceItem(
          id: '',
          name: suggestion.name,
          address: suggestion.address,
          lat: suggestion.lat,
          lng: suggestion.lng,
          category: suggestion.category,
        ),
      );

      await _loadPlaces();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${suggestion.name}을(를) 장소에 추가했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('장소 추가 실패: $e')),
        );
      }
    }
  }

  Future<void> _addPlace() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceSearchSheet(
        roomId: widget.roomId,
        onPlaceSelected:
            (name, address, lat, lng, category) async {
          final newPlace = PlaceItem(
            id: '',
            name: name,
            address: address,
            lat: lat,
            lng: lng,
            category: category,
          );

          try {
            await SupabaseRepository()
                .addPlace(widget.roomId, newPlace);

            await _loadPlaces();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('장소가 추가되었습니다.'),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('장소 추가 실패: $e'),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deletePlace(PlaceItem place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('장소 삭제'),
        content: Text(
          "'${place.name}'을(를) 삭제할까요?\n"
          '이 장소가 포함된 코스가 있다면 해당 스탑은 '
          '"(삭제된 장소)"로 표시됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final removedIndex = _places.indexOf(place);

    setState(() {
      _places.remove(place);
    });

    try {
      await SupabaseRepository().deletePlace(place.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('장소가 삭제되었습니다.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _places.insert(
            removedIndex.clamp(0, _places.length),
            place,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('장소 삭제 실패: $e'),
          ),
        );
      }
    }
  }

  Future<void> _votePlace(PlaceItem place) async {
    final index =
        _places.indexWhere((p) => p.id == place.id);

    if (index == -1) return;

    final wasVoted = place.hasMyVote;

    final optimistic = PlaceItem(
      id: place.id,
      name: place.name,
      address: place.address,
      lat: place.lat,
      lng: place.lng,
      category: place.category,
      votes: wasVoted
          ? place.votes - 1
          : place.votes + 1,
      hasMyVote: !wasVoted,
    );

    setState(() {
      _places[index] = optimistic;
    });

    try {
      await SupabaseRepository().votePlace(place.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _places[index] = place;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('투표 실패: $e'),
          ),
        );
      }
    }
  }

  Future<void> _openNearbyPlaces(
    MidpointRecommendation rec,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NearbyPlacesSheet(
        roomId: widget.roomId,
        region: rec,
        alreadyAddedNames: _places
            .map((p) => '${p.name}_${p.lat}_${p.lng}')
            .toSet(),
      ),
    );

    // 시트에서 장소를 추가했을 수 있으니 목록을 갱신한다.
    await _loadPlaces();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _places.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i < _places.length) {
              final place = _places[i];

              return _PlaceCard(
                place: place,
                onVote: () => _votePlace(place),
                onDelete: () => _deletePlace(place),
              );
            }

            if (i == _places.length) {
              return _travelType == 'solo'
                  ? _buildSoloRecommendationSection()
                  : _buildAiRecommendationSection();
            }

            return _places.isEmpty
                ? _buildEmptyState()
                : const SizedBox.shrink();
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add_place',
            onPressed: _addPlace,
            backgroundColor: AppColors.room,
            icon: const Icon(Icons.add_location_alt),
            label: const Text('장소 추가'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.place_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            '등록된 장소가 없습니다.',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const Text(
            '여행 가고 싶은 장소를 추가해보세요!',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoloRecommendationSection() {
    return Container(
      margin: const EdgeInsets.only(
        top: 24,
        bottom: 80,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.room.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.room.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.room,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '혼자 여행 추천',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.room,
                  ),
                ),
              ),
              if (!_soloLoading)
                IconButton(
                  onPressed: _loadSoloRecommendations,
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: AppColors.room,
                  ),
                  tooltip: '다시 추천받기',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_departure != null)
            Text(
              '${_departure!.address} 근처에서 혼자 즐기기 좋은 장소를 추천해요.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          else
            const Text(
              '출발지 근처에서 혼자 즐기기 좋은 장소를 추천해요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 12),
          if (_soloLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_soloError != null)
            Text(
              _soloError!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else if (_soloRecommendations.isEmpty)
            const Text(
              '주변에서 추천할 장소를 찾지 못했습니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else
            ..._soloRecommendations.map(
              (place) => _SoloRecommendationCard(
                place: place,
                onAdd: () => _addRecommendedPlace(place),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiRecommendationSection() {
    return Container(
      margin: const EdgeInsets.only(
        top: 24,
        bottom: 80,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.purple,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '만나기 좋은 동네 추천',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
              if (!_midpointLoading)
                IconButton(
                  onPressed: () =>
                      _loadMidpoints(forceRefresh: true),
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: Colors.purple,
                  ),
                  tooltip: '다시 계산',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_midpointLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (_midpointError != null)
            Text(
              _midpointError!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else if (_midpoints.isEmpty)
            const Text(
              '추천할 동네가 없습니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            const Text(
              '참가자들의 출발 위치를 기준으로 계산한 동네예요. '
              '탭하면 주변 장소를 추천해드려요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ..._midpoints.map(
              (m) => _MidpointCard(
                rec: m,
                onTap: () => _openNearbyPlaces(m),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoloRecommendationCard extends StatelessWidget {
  final PlaceSuggestion place;
  final VoidCallback onAdd;

  const _SoloRecommendationCard({
    required this.place,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final info = getCategoryInfo(place.category);
    final distance =
        place.distanceMeters < 1000
            ? '${place.distanceMeters.round()}m'
            : '${(place.distanceMeters / 1000).toStringAsFixed(1)}km';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.room.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              info.icon,
              color: info.color,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  place.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$distance · ${place.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.room,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _MidpointCard extends StatelessWidget {
  final MidpointRecommendation rec;
  final VoidCallback onTap;

  const _MidpointCard({
    required this.rec,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.purple.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    Colors.purple.withOpacity(0.12),
                child: Text(
                  '${rec.rank}',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.regionName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '평균 이동거리 약 ${rec.avgDistanceKm}km · '
                      '카페 ${rec.cafeCount} · '
                      '음식점 ${rec.restaurantCount} · '
                      '놀거리 ${rec.activityCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PlaceItem place;
  final VoidCallback onVote;
  final VoidCallback onDelete;

  const _PlaceCard({
    required this.place,
    required this.onVote,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final info = getCategoryInfo(place.category);

    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: info.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            info.icon,
            color: info.color,
            size: 22,
          ),
        ),
        title: Text(
          place.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          place.address,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: onVote,
              style: ElevatedButton.styleFrom(
                backgroundColor: place.hasMyVote
                    ? AppColors.room
                    : AppColors.room.withOpacity(0.1),
                foregroundColor: place.hasMyVote
                    ? Colors.white
                    : AppColors.room,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    place.hasMyVote
                        ? Icons.thumb_up_alt
                        : Icons.thumb_up_alt_outlined,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text('${place.votes}'),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
              ),
              color: AppColors.textSecondary,
              tooltip: '장소 삭제',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}