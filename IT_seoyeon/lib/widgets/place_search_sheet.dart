import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=10&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'TravelTogetherApp/1.0'});

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('검색 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  String _formatAddress(Map<String, dynamic> addr) {
    final List<String> parts = [];
    if (addr.containsKey('province')) parts.add(addr['province']);
    if (addr.containsKey('city')) parts.add(addr['city']);
    if (addr.containsKey('borough')) parts.add(addr['borough']);
    if (addr.containsKey('suburb')) parts.add(addr['suburb']);
    if (addr.containsKey('road')) parts.add(addr['road']);
    if (addr.containsKey('house_number')) parts.add(addr['house_number']);

    return parts.join(' ').trim();
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
                        final result = _searchResults[i];
                        final name = result['display_name'].split(',')[0];
                        final address = _formatAddress(result['address'] ?? {});
                        final type = result['type'] as String?;
                        final info = getCategoryInfo(type);

                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: info.color.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(info.icon, color: info.color, size: 18),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(address.isEmpty ? result['display_name'] : address,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            widget.onPlaceSelected(
                              name,
                              address.isEmpty ? result['display_name'] : address,
                              double.parse(result['lat']),
                              double.parse(result['lon']),
                              type,
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