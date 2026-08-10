import 'package:flutter/material.dart';

import '../core/group_scoring_service.dart';
import '../core/supabase_repository.dart';
import '../models/models.dart';
import 'category_utils.dart';

class PlaceSearchSheet extends StatefulWidget {
  final Function(
    String name,
    String address,
    double lat,
    double lng,
    String? category,
  ) onPlaceSelected;

  final String title;
  final String hintText;
  final String roomId;

  // 그룹 적합도 표시 여부
  // 기본값은 true: 장소 추천/장소 검색에서는 표시
  // 출발지 검색에서는 false로 전달
  final bool showGroupScore;

  const PlaceSearchSheet({
    super.key,
    required this.onPlaceSelected,
    this.title = '어디로 여행 가고 싶으신가요?',
    this.hintText = '장소 검색 (예: 제주공항, 성산일출봉)',
    required this.roomId,
    this.showGroupScore = true,
  });

  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<PlaceSearchSheet> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, GroupScoreResult> _scores = {};
  List<RoomMember> _members = [];

  bool _isSearching = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();

    // 그룹 적합도가 필요한 경우에만 팀원 정보를 불러온다.
    if (widget.showGroupScore) {
      _loadMembers();
    } else {
      _isInitialLoading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members =
          await SupabaseRepository().getMembers(widget.roomId);

      if (!mounted) return;

      setState(() {
        _members = members;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _scores = {};
    });

    try {
      final results =
          await SupabaseRepository().searchPlaces(query);

      final parsedResults = results
          .whereType<Map>()
          .map(
            (place) => Map<String, dynamic>.from(place),
          )
          .toList();

      if (!mounted) return;

      // 검색 결과는 먼저 표시한다.
      setState(() {
        _searchResults = parsedResults;
      });

      // 그룹 적합도 표시가 필요한 경우에만 점수를 계산한다.
      if (!widget.showGroupScore || _members.isEmpty) {
        return;
      }

      final futures = parsedResults.map((place) async {
        try {
          final lat = double.parse(
            place['y'].toString(),
          );

          final lng = double.parse(
            place['x'].toString(),
          );

          final score =
              await GroupScoringService.evaluatePlace(
            _members,
            lat,
            lng,
          );

          final placeId = place['id']?.toString();

          if (placeId == null || score == null) {
            return null;
          }

          return MapEntry(placeId, score);
        } catch (_) {
          return null;
        }
      }).toList();

      final entries = await Future.wait(futures);

      if (!mounted) return;

      setState(() {
        for (final entry in entries) {
          if (entry != null) {
            _scores[entry.key] = entry.value;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('검색 실패: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchResults = [];
                    _scores = {};
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onSubmitted: _searchPlaces,
          ),

          const SizedBox(height: 16),

          if (_isInitialLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_isSearching && _searchResults.isEmpty)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? '검색어를 입력해주세요.'
                            : '검색 결과가 없습니다.',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(),
                      itemBuilder: (context, i) {
                        final result = _searchResults[i];

                        final name =
                            result['place_name']?.toString() ?? '';

                        final roadAddress =
                            result['road_address_name']
                                    ?.toString() ??
                                '';

                        final lotAddress =
                            result['address_name']?.toString() ?? '';

                        final address = roadAddress.isNotEmpty
                            ? roadAddress
                            : lotAddress;

                        final categoryCode =
                            result['category_group_code']
                                ?.toString();

                        final info =
                            getCategoryInfo(categoryCode);

                        final placeId =
                            result['id']?.toString();

                        final score = placeId == null
                            ? null
                            : _scores[placeId];

                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  info.color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              info.icon,
                              color: info.color,
                              size: 18,
                            ),
                          ),

                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                address,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                ),
                              ),

                              // 장소 추천/장소 검색에서만 표시
                              if (widget.showGroupScore &&
                                  score != null) ...[
                                const SizedBox(height: 5),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.people_alt_outlined,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '그룹 적합도: ${score.label}',
                                        style:
                                            const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  '평균 ${score.avgMinutes}분 · '
                                  '최대 ${score.maxMinutes}분 · '
                                  '차이 ${score.balanceMinutes}분',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          onTap: () {
                            final lat = double.parse(
                              result['y'].toString(),
                            );

                            final lng = double.parse(
                              result['x'].toString(),
                            );

                            widget.onPlaceSelected(
                              name,
                              address,
                              lat,
                              lng,
                              categoryCode,
                            );

                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}