import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Supabase 없이 로컬 데이터를 관리하는 클래스
class LocalRepository {
  static const String _roomsKey = 'local_rooms';
  static const String _userKey = 'local_user';

  // 싱글톤 패턴
  static final LocalRepository _instance = LocalRepository._internal();
  factory LocalRepository() => _instance;
  LocalRepository._internal();

  /// 가상의 현재 유저 정보 (로그인 대신 사용)
  Future<UserProfile> getMyProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return UserProfile.fromJson(jsonDecode(userStr));
    }

    // 기본 유저 생성
    final defaultUser = UserProfile(
      id: 'local-user-id',
      nickname: '여행자',
      email: 'traveler@example.com',
    );
    await prefs.setString(_userKey, jsonEncode({
      'id': defaultUser.id,
      'nickname': defaultUser.nickname,
      'email': defaultUser.email,
    }));
    return defaultUser;
  }

  /// 모든 방 목록 가져오기
  Future<List<TravelRoom>> getRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsStr = prefs.getString(_roomsKey);
    if (roomsStr == null) return [];

    final List<dynamic> decoded = jsonDecode(roomsStr);
    return decoded.map((item) => TravelRoom.fromJson(item)).toList();
  }

  /// 새 방 추가하기
  Future<void> addRoom(TravelRoom room) async {
    final rooms = await getRooms();
    rooms.insert(0, room); // 최신 방이 위로 오게 추가

    final prefs = await SharedPreferences.getInstance();
    final encoded = rooms.map((r) => _roomToJson(r)).toList();
    await prefs.setString(_roomsKey, jsonEncode(encoded));
  }

  /// 특정 방의 내 출발 정보 가져오기
  Future<DepartureInfo?> getDepartureInfo(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final user = await getMyProfile();
    final key = 'departure_${roomId}_${user.id}';
    final data = prefs.getString(key);
    if (data == null) return null;
    return DepartureInfo.fromJson(jsonDecode(data));
  }

  /// 내 출발 정보 저장하기
  Future<void> saveDepartureInfo(DepartureInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'departure_${info.roomId}_${info.userId}';
    await prefs.setString(key, jsonEncode(info.toJson()));
  }

  /// 특정 방의 장소 목록 가져오기
  Future<List<PlaceItem>> getPlaces(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'places_$roomId';
    final data = prefs.getString(key);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => PlaceItem.fromJson(item)).toList();
  }

  /// 장소 추가하기
  Future<void> addPlace(String roomId, PlaceItem place) async {
    final places = await getPlaces(roomId);
    places.add(place);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('places_$roomId', jsonEncode(places.map((e) => e.toJson()).toList()));
  }

  /// 특정 방의 코스 목록 가져오기
  Future<List<CourseItem>> getCourses(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'courses_$roomId';
    final data = prefs.getString(key);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => CourseItem.fromJson(item)).toList();
  }

  /// 코스 추가하기
  Future<void> addCourse(String roomId, CourseItem course) async {
    final courses = await getCourses(roomId);
    courses.add(course);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courses_$roomId', jsonEncode(courses.map((e) => e.toJson()).toList()));
  }

  /// 특정 방의 멤버 목록 가져오기 (가상)
  Future<List<RoomMember>> getMembers(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'members_$roomId';
    final data = prefs.getString(key);
    if (data == null) {
      // 데이터가 없으면 본인이라도 넣어줌
      final myProfile = await getMyProfile();
      final owner = RoomMember(
        userId: myProfile.id,
        nickname: myProfile.nickname,
        role: MemberRole.owner,
        email: myProfile.email,
      );
      await saveMembers(roomId, [owner]);
      return [owner];
    }
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => RoomMember.fromJson(item)).toList();
  }

  /// 멤버 목록 저장하기
  Future<void> saveMembers(String roomId, List<RoomMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('members_$roomId', jsonEncode(members.map((e) => e.toJson()).toList()));
  }

  /// 가용 날짜 저장하기
  Future<void> saveAvailability(String roomId, List<DateTime> dates) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await getMyProfile();
    final availability = DateAvailability(
      userId: profile.id,
      nickname: profile.nickname,
      availableDates: dates,
    );

    final key = 'availability_$roomId';
    final currentStr = prefs.getString(key);
    List<DateAvailability> allList = [];
    if (currentStr != null) {
      final List<dynamic> decoded = jsonDecode(currentStr);
      allList = decoded.map((e) => DateAvailability.fromJson(e)).toList();
    }

    // 기존 내 정보 삭제 후 새로 추가
    allList.removeWhere((e) => e.userId == profile.id);
    allList.add(availability);

    await prefs.setString(key, jsonEncode(allList.map((e) => e.toJson()).toList()));
  }

  /// 모든 가용 날짜 정보 가져오기
  Future<List<DateAvailability>> getAllAvailabilities(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('availability_$roomId');
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => DateAvailability.fromJson(e)).toList();
  }

  /// 방 정보 업데이트 (날짜 확정 등)
  Future<void> updateRoom(TravelRoom room) async {
    final rooms = await getRooms();
    final index = rooms.indexWhere((r) => r.id == room.id);
    if (index != -1) {
      rooms[index] = room;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roomsKey, jsonEncode(rooms.map((r) => r.toJson()).toList()));
    }
  }

  /// TravelRoom을 JSON으로 변환 (이제 모델의 toJson 활용)
  Map<String, dynamic> _roomToJson(TravelRoom room) => room.toJson();
}

