import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/place_search_sheet.dart';
import 'room_dashboard_screen.dart';

class DepartureInfoScreen extends StatefulWidget {
  final String roomId;
  const DepartureInfoScreen({super.key, required this.roomId});

  @override
  State<DepartureInfoScreen> createState() => _DepartureInfoScreenState();
}

class _DepartureInfoScreenState extends State<DepartureInfoScreen> {
  final _nicknameController = TextEditingController();
  final _addressController = TextEditingController();
  TransportMode _selectedTransport = TransportMode.car;
  bool _isLoading = true;
  bool _isGpsLoading = false;
  double _lat = 0.0;
  double _lng = 0.0;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final repo = SupabaseRepository();
      final profile = await repo.getMyProfile();
      final info = await repo.getDepartureInfo(widget.roomId);

      if (mounted) {
        setState(() {
          _nicknameController.text = info?.nickname ?? profile.nickname;
          _addressController.text = info?.address ?? '';
          _selectedTransport = info?.transport ?? TransportMode.car;
          _lat = info?.lat ?? 0.0;
          _lng = info?.lng ?? 0.0;
          _isLoading = false;
        });
        if (_lat != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(LatLng(_lat, _lng), 15);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddressSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceSearchSheet(
        title: '출발지 주소를 검색하세요',
        hintText: '예: 서울역, 강남구 테헤란로 123',
        onPlaceSelected: (name, address, lat, lng, category) {
          if (!mounted) return;
          setState(() {
            _addressController.text = address;
            _lat = lat;
            _lng = lng;
          });
          _mapController.move(LatLng(lat, lng), 15);
        },
      ),
    );
  }

  Future<void> _applyGpsLocation() async {
    setState(() => _isGpsLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw '위치 권한이 거부되었습니다.';
      }
      if (permission == LocationPermission.deniedForever) throw '위치 권한이 영구적으로 거부되었습니다.';

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _updateLocation(position.latitude, position.longitude);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('현재 위치가 반영되었습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('실패: $e')));
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  Future<void> _updateLocation(double lat, double lng, {bool moveMap = true}) async {
    String formattedAddress = '';
    if (kIsWeb) {
      try {
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
        final response = await http.get(url, headers: {'User-Agent': 'TravelTogetherApp/1.0', 'Accept-Language': 'ko-KR'});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final addr = data['address'] as Map<String, dynamic>;
          final List<String> parts = [];
          if (addr.containsKey('province')) parts.add(addr['province']);
          if (addr.containsKey('city')) parts.add(addr['city']);
          if (addr.containsKey('borough')) parts.add(addr['borough']);
          if (addr.containsKey('suburb')) parts.add(addr['suburb']);
          if (addr.containsKey('road')) parts.add(addr['road']);
          if (addr.containsKey('house_number')) parts.add(addr['house_number']);
          formattedAddress = parts.join(' ').trim();
          if (formattedAddress.isEmpty) formattedAddress = data['display_name'];
        }
      } catch (_) {}
    } else {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final List<String> parts = [];
          if (pm.administrativeArea != null) parts.add(pm.administrativeArea!);
          if (pm.locality != null) parts.add(pm.locality!);
          if (pm.subLocality != null) parts.add(pm.subLocality!);
          if (pm.thoroughfare != null) parts.add(pm.thoroughfare!);
          if (pm.subThoroughfare != null) parts.add(pm.subThoroughfare!);
          formattedAddress = parts.join(' ').trim();
        }
      } catch (_) {}
    }

    if (formattedAddress.isEmpty) formattedAddress = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

    if (mounted) {
      setState(() {
        _addressController.text = formattedAddress;
        _lat = lat;
        _lng = lng;
      });
      if (moveMap) _mapController.move(LatLng(lat, lng), 15);
    }
  }

  Future<void> _saveInfo() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('출발지 주소를 설정해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = SupabaseRepository();
      final profile = await repo.getMyProfile();
      final info = DepartureInfo(
        roomId: widget.roomId,
        userId: profile.id,
        nickname: _nicknameController.text.trim(),
        transport: _selectedTransport,
        address: _addressController.text,
        lat: _lat,
        lng: _lng,
      );

      await repo.saveDepartureInfo(info);

      if (mounted) {
        final rooms = await repo.getRooms();
        final room = rooms.firstWhere((r) => r.id == widget.roomId);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RoomDashboardScreen(room: room)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('내 출발 정보 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(step: 1, title: '내 출발 정보 등록'),
            const SizedBox(height: 24),
            const Text('닉네임', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _nicknameController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '닉네임을 입력하세요')),
            const SizedBox(height: 20),
            const Text('이동 수단', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<TransportMode>(
              value: _selectedTransport,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: TransportMode.car, child: Text('자동차')),
                DropdownMenuItem(value: TransportMode.public_walk, child: Text('대중교통(도보)')),
                DropdownMenuItem(value: TransportMode.bicycle, child: Text('자전거')),
              ],
              onChanged: (val) { if (val != null) setState(() => _selectedTransport = val); },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('출발지 주소 설정', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (_lat != 0) const Text('지도에서 위치를 탭하여 변경할 수 있습니다.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _openAddressSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('주소 검색으로 설정'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
                TextButton.icon(
                  onPressed: _isGpsLoading ? null : _applyGpsLocation,
                  icon: _isGpsLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location, size: 18),
                  label: Text(_isGpsLoading ? '위치 찾는 중...' : 'GPS 기반 위치 적용'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              readOnly: true,
              onTap: _openAddressSearch,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '주소를 검색하거나 GPS로 설정해주세요',
                suffixIcon: _lat != 0 ? const Icon(Icons.check_circle, color: Colors.green) : null,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 350,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: Colors.indigo.withOpacity(0.1))),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_lat != 0 ? _lat : 37.5665, _lng != 0 ? _lng : 126.9780),
                      initialZoom: _lat != 0 ? 15 : 11,
                      onTap: (tapPosition, point) => _updateLocation(point.latitude, point.longitude, moveMap: false),
                    ),
                    children: [
                      TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd'], userAgentPackageName: 'com.example.travel_together_app'),
                      if (_lat != 0) MarkerLayer(markers: [Marker(point: LatLng(_lat, _lng), width: 60, height: 60, child: _buildCustomMarker())]),
                    ],
                  ),
                  Positioned(right: 12, top: 12, child: Column(children: [_MapControlButton(icon: Icons.add, onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)), const SizedBox(height: 8), _MapControlButton(icon: Icons.remove, onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1))])),
                  if (_lat == 0) Container(color: Colors.white.withOpacity(0.8), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map_outlined, size: 48, color: Colors.indigo), SizedBox(height: 12), Text('위치를 등록하면 지도가 표시됩니다.', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))]))),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(onPressed: _saveInfo, style: FilledButton.styleFrom(backgroundColor: Colors.indigo, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.save), label: const Text('내 정보 저장 및 다음 단계로 이동')),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMarker() {
    return Stack(alignment: Alignment.center, children: [Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.2), shape: BoxShape.circle)), const Icon(Icons.location_on, color: Colors.indigo, size: 40), Positioned(top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))]);
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _MapControlButton({required this.icon, required this.onPressed});
  @override Widget build(BuildContext context) { return Material(color: Colors.white, elevation: 4, borderRadius: BorderRadius.circular(8), child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(8), child: Container(width: 36, height: 36, alignment: Alignment.center, child: Icon(icon, color: Colors.indigo, size: 20)))); }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final String title;
  const _StepHeader({required this.step, required this.title});
  @override Widget build(BuildContext context) { return Row(children: [Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle), child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Text('STEP $step. $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]); }
}