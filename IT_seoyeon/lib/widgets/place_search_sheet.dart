import 'package:flutter/material.dart';
import '../core/supabase_repository.dart';
import '../core/theme.dart';
import 'category_utils.dart';

class PlaceSearchSheet extends StatefulWidget {
  final Function(String name, String address, double lat, double lng, String? category) onPlaceSelected;
  final String title;
  final String hintText;
  const PlaceSearchSheet({
    super.key,
    required this.onPlaceSelected,
    this.title = '어디로 여행 가고 싶으신가요?',
    this.hintText = '장소 검색 (예: 제주공항, 성산일출봉)',
  });

  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<PlaceSearchSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results = await SupabaseRepository().searchPlaces(query);
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('검색 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear()),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onSubmitted: _searchPlaces,
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(child: Text(_searchController.text.isEmpty ? '검색어를 입력해주세요.' : '검색 결과가 없습니다.',
                      style: const TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final result = _searchResults[i] as Map<String, dynamic>;
                        final name = result['place_name'] as String? ?? '';
                        final roadAddress = result['road_address_name'] as String? ?? '';
                        final lotAddress = result['address_name'] as String? ?? '';
                        final address = roadAddress.isNotEmpty ? roadAddress : lotAddress;
                        final categoryCode = result['category_group_code'] as String?;
                        final info = getCategoryInfo(categoryCode);

                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: info.color.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(info.icon, color: info.color, size: 18),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(address,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            widget.onPlaceSelected(
                              name,
                              address,
                              double.parse(result['y'] as String),
                              double.parse(result['x'] as String),
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