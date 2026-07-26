/// 방 상태: 계획중 / 여행중 / 완료 (플로우차트 하단 상태 흐름과 일치)
enum RoomStatus { planning, traveling, completed }

class UserProfile {
  final String id;
  final String nickname;
  final String email;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.nickname,
    required this.email,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        nickname: json['nickname'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class TravelRoom {
  final String id;
  final String name;
  final int memberCount;
  final RoomStatus status;
  final String? coverImageUrl;
  final DateTime? startDate;
  final DateTime? endDate;

  TravelRoom({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.status,
    this.coverImageUrl,
    this.startDate,
    this.endDate,
  });

  factory TravelRoom.fromJson(Map<String, dynamic> json) => TravelRoom(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        memberCount: json['member_count'] as int? ?? 0,
        status: RoomStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? 'planning'),
          orElse: () => RoomStatus.planning,
        ),
        coverImageUrl: json['cover_image_url'] as String?,
        startDate: json['start_date'] != null
            ? DateTime.tryParse(json['start_date'] as String)
            : null,
        endDate: json['end_date'] != null
            ? DateTime.tryParse(json['end_date'] as String)
            : null,
      );
}

/// 일정 확정 상태 (투표중 / 확정)
enum ScheduleStatus { voting, confirmed }

class ScheduleItem {
  final String id;
  final String roomId;
  final DateTime date;
  final String title;
  final String? location;
  final ScheduleStatus status;

  ScheduleItem({
    required this.id,
    required this.roomId,
    required this.date,
    required this.title,
    this.location,
    required this.status,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: json['id'] as String,
        roomId: json['room_id'] as String,
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String? ?? '',
        location: json['location'] as String?,
        status: ScheduleStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? 'voting'),
          orElse: () => ScheduleStatus.voting,
        ),
      );
}

class RecordItem {
  final String id;
  final String roomId;
  final String placeName;
  final String? memo;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;

  RecordItem({
    required this.id,
    required this.roomId,
    required this.placeName,
    this.memo,
    this.imageUrl,
    required this.createdAt,
    this.likeCount = 0,
  });

  factory RecordItem.fromJson(Map<String, dynamic> json) => RecordItem(
        id: json['id'] as String,
        roomId: json['room_id'] as String,
        placeName: json['place_name'] as String? ?? '',
        memo: json['memo'] as String?,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        likeCount: json['like_count'] as int? ?? 0,
      );
}
