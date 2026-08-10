enum RoomStatus { planning, traveling, completed }
enum ScheduleStatus { voting, confirmed }
enum TransportMode { car, public_walk, bicycle }
enum MemberRole { owner, member }
enum RecordVisibility { private, friends, public }
enum InvitationStatus { pending, accepted, declined, canceled }
enum SchedulePhase { collecting, approval, voting, finalized }

DateTime? parseDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

class UserProfile {
  final String id;
  final String nickname;
  final String email;
  final String userId;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    required this.nickname,
    required this.email,
    this.userId = '',
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'].toString(),
        nickname: json['nickname'] as String? ?? '',
        email: json['email'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'email': email,
        'user_id': userId,
        'avatar_url': avatarUrl,
      };
}

class TravelRoom {
  final String id;
  final String name;
  final String? inviteCode;
  final int memberCount;
  final RoomStatus status;
  final String? coverImageUrl;
  final int tripDays;
  final bool placeRecommendationEnabled;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? confirmedDate;
  final DateTime? scheduleLockedAt;
  final String schedulePhase;
  final String? createdBy;

  const TravelRoom({
    required this.id,
    required this.name,
    this.inviteCode,
    this.memberCount = 0,
    this.status = RoomStatus.planning,
    this.coverImageUrl,
    this.tripDays = 1,
    this.placeRecommendationEnabled = true,
    this.startDate,
    this.endDate,
    this.confirmedDate,
    this.scheduleLockedAt,
    this.schedulePhase = 'collecting',
    this.createdBy,
  });

  factory TravelRoom.fromJson(Map<String, dynamic> json) => TravelRoom(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        inviteCode: json['invite_code'] as String?,
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        status: RoomStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? 'planning'),
          orElse: () => RoomStatus.planning,
        ),
        coverImageUrl: json['cover_image_url'] as String?,
        tripDays: (json['trip_days'] as num?)?.toInt() ?? 1,
        placeRecommendationEnabled:
            json['place_recommendation_enabled'] as bool? ?? true,
        startDate: parseDate(json['start_date']),
        endDate: parseDate(json['end_date']),
        confirmedDate: parseDate(json['confirmed_date']),
        scheduleLockedAt: parseDate(json['schedule_locked_at']),
        schedulePhase: json['schedule_phase'] as String? ?? 'collecting',
        createdBy: json['created_by']?.toString(),
      );

  String get tripDurationLabel =>
      tripDays <= 1 ? '당일치기' : '${tripDays - 1}박 $tripDays일';

  /// 여행 날짜를 사람이 읽기 좋은 형태로 표시한다.
  /// 시작일과 종료일이 같은 날(당일치기)이면 "8/19"처럼 하루만 표시하고,
  /// 여러 날에 걸치면 "8/19~8/21"처럼 범위로 표시한다.
  String get tripDateRangeLabel {
    final start = startDate;
    if (start == null) return '';
    final end = endDate ?? start;
    final startLabel = '${start.month}/${start.day}';
    final isSameDay =
        start.year == end.year && start.month == end.month && start.day == end.day;
    if (isSameDay) return startLabel;
    final endLabel = '${end.month}/${end.day}';
    return '$startLabel~$endLabel';
  }

  bool get isScheduleFinalized => scheduleLockedAt != null || startDate != null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'invite_code': inviteCode,
        'status': status.name,
        'cover_image_url': coverImageUrl,
        'trip_days': tripDays,
        'place_recommendation_enabled': placeRecommendationEnabled,
      };
}

class DateAvailability {
  final String userId;
  final String nickname;
  final List<DateTime> availableDates;
  final bool submitted;

  const DateAvailability({
    required this.userId,
    required this.nickname,
    required this.availableDates,
    this.submitted = true,
  });

  factory DateAvailability.fromJson(Map<String, dynamic> json) {
    final dates = (json['available_dates'] as List<dynamic>? ?? const []);
    return DateAvailability(
      userId: json['user_id'].toString(),
      nickname: json['profiles']?['nickname'] as String? ??
          json['nickname'] as String? ??
          '',
      availableDates:
          dates.map((e) => DateTime.parse(e.toString())).toList(),
      submitted: json['submitted'] as bool? ?? true,
    );
  }
  Map<String,dynamic> toJson()=>{
    'user_id':userId,'nickname':nickname,
    'available_dates':availableDates.map((e)=>e.toIso8601String().split('T').first).toList(),
    'submitted':submitted,
  };
}

class ScheduleCandidate {
  final String id;
  final String roomId;
  final DateTime startDate;
  final DateTime endDate;
  final int availableMemberCount;
  final int round;
  final int voteCount;
  final bool? myApproval;
  final bool hasMyVote;

  const ScheduleCandidate({
    required this.id,
    required this.roomId,
    required this.startDate,
    required this.endDate,
    required this.availableMemberCount,
    this.round = 1,
    this.voteCount = 0,
    this.myApproval,
    this.hasMyVote = false,
  });

  factory ScheduleCandidate.fromJson(Map<String, dynamic> json) =>
      ScheduleCandidate(
        id: json['id'].toString(),
        roomId: json['room_id'].toString(),
        startDate: DateTime.parse(json['start_date'].toString()),
        endDate: DateTime.parse(json['end_date'].toString()),
        availableMemberCount:
            (json['available_member_count'] as num?)?.toInt() ?? 0,
        round: (json['round'] as num?)?.toInt() ?? 1,
        voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
        myApproval: json['my_approval'] as bool?,
        hasMyVote: json['has_my_vote'] as bool? ?? false,
      );
}

class RoomMember {
  final String userId;
  final String nickname;
  final MemberRole role;
  final String? email;
  final String? avatarUrl;
  final DepartureInfo? departure;

  const RoomMember({
    required this.userId,
    required this.nickname,
    required this.role,
    this.email,
    this.avatarUrl,
    this.departure,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return RoomMember(
      userId: json['user_id'].toString(),
      nickname: json['nickname'] as String? ??
          profile?['nickname'] as String? ??
          '',
      role: MemberRole.values.firstWhere(
        (e) => e.name == (json['role'] as String? ?? 'member'),
        orElse: () => MemberRole.member,
      ),
      email: profile?['email'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      departure:
          json['address'] != null ? DepartureInfo.fromJson(json) : null,
    );
  }
  Map<String,dynamic> toJson()=>{
    'user_id':userId,'nickname':nickname,'role':role.name,
  };
}

class DepartureInfo {
  final String roomId;
  final String userId;
  final String nickname;
  final TransportMode transport;
  final String address;
  final double lat;
  final double lng;

  const DepartureInfo({
    required this.roomId,
    required this.userId,
    required this.nickname,
    required this.transport,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory DepartureInfo.fromJson(Map<String, dynamic> json) => DepartureInfo(
        roomId: json['room_id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        nickname: json['nickname'] as String? ?? '',
        transport: TransportMode.values.firstWhere(
          (e) => e.name == (json['transport'] as String? ?? 'car'),
          orElse: () => TransportMode.car,
        ),
        address: json['address'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'transport': transport.name,
        'address': address,
        'lat': lat,
        'lng': lng,
      };
}

/// 중간지점 추천 동네 하나. calculate-midpoint Edge Function 응답을 파싱한다.
class MidpointRecommendation {
  final int rank;
  final double lat;
  final double lng;
  final String regionName;
  final int cafeCount;
  final int restaurantCount;
  final int activityCount;
  final double avgDistanceKm;

  const MidpointRecommendation({
    required this.rank,
    required this.lat,
    required this.lng,
    required this.regionName,
    required this.cafeCount,
    required this.restaurantCount,
    required this.activityCount,
    required this.avgDistanceKm,
  });

  factory MidpointRecommendation.fromJson(Map<String, dynamic> json) =>
      MidpointRecommendation(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        regionName: json['region_name'] as String? ?? '',
        cafeCount: (json['cafe_count'] as num?)?.toInt() ?? 0,
        restaurantCount: (json['restaurant_count'] as num?)?.toInt() ?? 0,
        activityCount: (json['activity_count'] as num?)?.toInt() ?? 0,
        avgDistanceKm: (json['avg_distance_km'] as num?)?.toDouble() ?? 0,
      );
}

class PersonalSchedule {
  final String id;
  final String title;
  final DateTime scheduleDate;
  final String? scheduleTime;
  final bool isAllDay;
  final String? memo;

  const PersonalSchedule({
    required this.id,
    required this.title,
    required this.scheduleDate,
    this.scheduleTime,
    this.isAllDay = false,
    this.memo,
  });

  factory PersonalSchedule.fromJson(Map<String, dynamic> json) =>
      PersonalSchedule(
        id: json['id'].toString(),
        title: json['title'] as String? ?? '',
        scheduleDate: DateTime.parse(json['schedule_date'].toString()),
        scheduleTime: json['schedule_time']?.toString(),
        isAllDay: json['is_all_day'] as bool? ?? false,
        memo: json['memo'] as String?,
      );
}

class RecordAlbum {
  final String id;
  final String ownerId;
  final DateTime recordDate;
  final String title;
  final RecordVisibility visibility;
  final String? roomId;
  final String? coverUrl;
  final String? ownerName;
  final String? ownerAvatar;
  final int photoCount;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  const RecordAlbum({
    required this.id,
    required this.ownerId,
    required this.recordDate,
    required this.title,
    required this.visibility,
    this.roomId,
    this.coverUrl,
    this.ownerName,
    this.ownerAvatar,
    this.photoCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
  });

  factory RecordAlbum.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return RecordAlbum(
      id: json['id'].toString(),
      ownerId: json['owner_id'].toString(),
      recordDate: DateTime.parse(json['record_date'].toString()),
      title: json['title'] as String? ?? '',
      visibility: RecordVisibility.values.firstWhere(
        (e) => e.name == (json['visibility'] as String? ?? 'private'),
        orElse: () => RecordVisibility.private,
      ),
      roomId: json['room_id']?.toString(),
      coverUrl: json['cover_url'] as String?,
      ownerName: profile?['nickname'] as String?,
      ownerAvatar: profile?['avatar_url'] as String?,
      photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  RecordAlbum copyWith({int? likeCount, int? commentCount, bool? isLiked}) =>
      RecordAlbum(
        id: id,
        ownerId: ownerId,
        recordDate: recordDate,
        title: title,
        visibility: visibility,
        roomId: roomId,
        coverUrl: coverUrl,
        ownerName: ownerName,
        ownerAvatar: ownerAvatar,
        photoCount: photoCount,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        isLiked: isLiked ?? this.isLiked,
      );
}

class RecordEntry {
  final String id;
  final String albumId;
  final String placeName;
  final String? address;
  final String? visitTime;
  final String? note;
  final int orderIndex;
  final List<RecordPhoto> photos;

  const RecordEntry({
    required this.id,
    required this.albumId,
    required this.placeName,
    this.address,
    this.visitTime,
    this.note,
    this.orderIndex = 0,
    this.photos = const [],
  });

  factory RecordEntry.fromJson(Map<String, dynamic> json) => RecordEntry(
        id: json['id'].toString(),
        albumId: json['album_id'].toString(),
        placeName: json['place_name'] as String? ?? '',
        address: json['address'] as String?,
        visitTime: json['visit_time']?.toString(),
        note: json['note'] as String?,
        orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
        photos: (json['record_photos'] as List<dynamic>? ?? const [])
            .map((e) => RecordPhoto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class RecordPhoto {
  final String id;
  final String url;
  final String storagePath;
  final int orderIndex;
  final bool isCover;

  const RecordPhoto({
    required this.id,
    required this.url,
    required this.storagePath,
    this.orderIndex = 0,
    this.isCover = false,
  });

  factory RecordPhoto.fromJson(Map<String, dynamic> json) => RecordPhoto(
        id: json['id'].toString(),
        url: json['url'] as String? ?? '',
        storagePath: json['storage_path'] as String? ?? '',
        orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
        isCover: json['is_cover'] as bool? ?? false,
      );
}

// Existing place/course/schedule/legacy record models are kept for the
// current room tabs while the new date-centred record feature uses albums.
class PlaceItem {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? category;
  final int votes;
  const PlaceItem({required this.id, required this.name, required this.address,
    required this.lat, required this.lng, this.category, this.votes = 0});
  factory PlaceItem.fromJson(Map<String, dynamic> j) => PlaceItem(
    id: j['id'].toString(), name: j['name'] ?? '', address: j['address'] ?? '',
    lat: (j['lat'] as num?)?.toDouble() ?? 0,
    lng: (j['lng'] as num?)?.toDouble() ?? 0,
    category: j['category'], votes: (j['votes'] as num?)?.toInt() ?? 0);
  Map<String,dynamic> toJson()=>{'name':name,'address':address,'lat':lat,'lng':lng,'category':category,'votes':votes};
}

/// 코스 안의 한 장소(스탑). 하루(CourseDay) 안에서의 순서와, 이 스탑이
/// "식사" 목적인지, 도착 예정 시각/직전 장소로부터의 이동 시간을 담는다.
class CourseStop {
  final String placeId;
  final int order;
  final bool isMeal;
  final String? mealType; // 'lunch' | 'dinner' | null
  final String? arrivalTime; // 'HH:mm'
  final int? travelMinutesFromPrev;

  const CourseStop({
    required this.placeId,
    required this.order,
    this.isMeal = false,
    this.mealType,
    this.arrivalTime,
    this.travelMinutesFromPrev,
  });

  factory CourseStop.fromJson(Map<String, dynamic> j) => CourseStop(
        placeId: j['place_id'].toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
        isMeal: j['is_meal'] as bool? ?? false,
        mealType: j['meal_type'] as String?,
        arrivalTime: j['arrival_time'] as String?,
        travelMinutesFromPrev: (j['travel_minutes_from_prev'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'place_id': placeId,
        'order': order,
        'is_meal': isMeal,
        'meal_type': mealType,
        'arrival_time': arrivalTime,
        'travel_minutes_from_prev': travelMinutesFromPrev,
      };
}

/// 여행 하루치 동선. dayNumber는 1부터 시작.
class CourseDay {
  final int dayNumber;
  final List<CourseStop> stops;

  const CourseDay({required this.dayNumber, required this.stops});

  factory CourseDay.fromJson(Map<String, dynamic> j) => CourseDay(
        dayNumber: (j['day_number'] as num?)?.toInt() ?? 1,
        stops: (j['stops'] as List<dynamic>? ?? [])
            .map((e) => CourseStop.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'day_number': dayNumber,
        'stops': stops.map((s) => s.toJson()).toList(),
      };
}

class CourseItem {
  final String id;
  final String name;
  final List<CourseDay> days;
  final int votes;
  final bool isConfirmed;

  const CourseItem({
    required this.id,
    required this.name,
    required this.days,
    this.votes = 0,
    this.isConfirmed = false,
  });

  /// 하위 호환용: 모든 날짜의 place id를 순서대로 펼친 리스트.
  List<String> get placeIds =>
      days.expand((d) => d.stops).map((s) => s.placeId).toList();

  factory CourseItem.fromJson(Map<String, dynamic> j) {
    List<CourseDay> parsedDays;
    final rawDays = j['days'] as List<dynamic>?;
    if (rawDays != null && rawDays.isNotEmpty) {
      parsedDays =
          rawDays.map((d) => CourseDay.fromJson(Map<String, dynamic>.from(d))).toList();
    } else {
      // days 컬럼이 없는 예전 데이터는 place_ids를 1일차로 취급한다.
      final ids = (j['place_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      parsedDays = ids.isEmpty
          ? []
          : [
              CourseDay(
                dayNumber: 1,
                stops: [
                  for (var i = 0; i < ids.length; i++)
                    CourseStop(placeId: ids[i], order: i),
                ],
              ),
            ];
    }
    return CourseItem(
      id: j['id'].toString(),
      name: j['name'] ?? '',
      days: parsedDays,
      votes: (j['votes'] as num?)?.toInt() ?? 0,
      isConfirmed: j['is_confirmed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'days': days.map((d) => d.toJson()).toList(),
        'place_ids': placeIds,
        'votes': votes,
        'is_confirmed': isConfirmed,
      };
}

/// calculate-midpoint이 아니라, 특정 좌표(동네) 주변의 실제 음식점/카페/놀거리
/// 추천 결과 하나. 아직 저장 전이라 id/votes가 없다는 점에서 PlaceItem과 다르다.
class PlaceSuggestion {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category; // 'restaurant' | 'cafe' | 'attraction' 등 (getCategoryInfo와 호환)
  final double distanceMeters;

  const PlaceSuggestion({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
    required this.distanceMeters,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) => PlaceSuggestion(
        name: j['name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        category: j['category'] as String? ?? '',
        distanceMeters: (j['distance_m'] as num?)?.toDouble() ?? 0,
      );
}

class ScheduleItem {
  final String id; final String roomId; final DateTime date; final String title;
  final String? location; final ScheduleStatus status;
  const ScheduleItem({required this.id,required this.roomId,required this.date,
    required this.title,this.location,required this.status});
  factory ScheduleItem.fromJson(Map<String,dynamic> j)=>ScheduleItem(
    id:j['id'].toString(),roomId:j['room_id'].toString(),
    date:DateTime.parse(j['date'].toString()),title:j['title']??'',location:j['location'],
    status:ScheduleStatus.values.firstWhere((e)=>e.name==(j['status']??'voting'),orElse:()=>ScheduleStatus.voting));
}

class RecordItem {
  final String id,roomId,placeName; final String? memo,imageUrl,authorId,authorName,authorAvatar;
  final DateTime createdAt; final int likeCount,commentCount;
  const RecordItem({required this.id,required this.roomId,required this.placeName,
    this.memo,this.imageUrl,required this.createdAt,this.likeCount=0,this.authorId,
    this.authorName,this.authorAvatar,this.commentCount=0});
  factory RecordItem.fromJson(Map<String,dynamic> j)=>RecordItem(
    id:j['id'].toString(),roomId:j['room_id'].toString(),placeName:j['place_name']??'',
    memo:j['memo'],imageUrl:j['image_url'],createdAt:DateTime.parse(j['created_at'].toString()),
    likeCount:(j['like_count'] as num?)?.toInt()??0,authorId:j['created_by']?.toString(),
    authorName:j['profiles']?['nickname'],authorAvatar:j['profiles']?['avatar_url'],
    commentCount:j['comments']?[0]?['count']??0);
  Map<String,dynamic> toJson()=>{'room_id':roomId,'place_name':placeName,'memo':memo,'image_url':imageUrl,'created_by':authorId};
}

class RecordComment {
  final String id,recordId,userId,userName,content; final String? userAvatar;
  final DateTime createdAt;
  const RecordComment({required this.id,required this.recordId,required this.userId,
    required this.userName,this.userAvatar,required this.content,required this.createdAt});
  factory RecordComment.fromJson(Map<String,dynamic> j)=>RecordComment(
    id:j['id'].toString(),recordId:j['record_id'].toString(),userId:j['user_id'].toString(),
    userName:j['profiles']?['nickname']??'알 수 없음',userAvatar:j['profiles']?['avatar_url'],
    content:j['content']??'',createdAt:DateTime.parse(j['created_at'].toString()));
}