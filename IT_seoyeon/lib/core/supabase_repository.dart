import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_client.dart';

class SupabaseRepository {
  static final SupabaseRepository _instance = SupabaseRepository._internal();
  factory SupabaseRepository() => _instance;
  SupabaseRepository._internal();

  String? get currentUserId => supabase.auth.currentUser?.id;
  String get _uid {
    final value = currentUserId;
    if (value == null) throw '로그인이 필요합니다.';
    return value;
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  String _date(DateTime d) => _day(d).toIso8601String().split('T').first;

  // Profile -----------------------------------------------------------------
  Future<UserProfile> getMyProfile() async {
    final data = await supabase.from('profiles').select('id,nickname,user_id,avatar_url').eq('id', _uid).single();
    return UserProfile.fromJson({...data, 'email': supabase.auth.currentUser?.email ?? ''});
  }

  Future<void> updateProfile({required String nickname, String? avatarUrl, bool clearAvatar = false}) async {
    await supabase.from('profiles').update({
      'nickname': nickname.trim(),
      if (avatarUrl != null || clearAvatar) 'avatar_url': avatarUrl,
      'email': supabase.auth.currentUser?.email,
    }).eq('id', _uid);
  }

  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final path = '$_uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await supabase.storage.from('avatars').uploadBinary(
      path, bytes, fileOptions: const FileOptions(upsert: true, cacheControl: '3600'));
    return supabase.storage.from('avatars').getPublicUrl(path);
  }

  // Rooms -------------------------------------------------------------------
  Future<List<TravelRoom>> getRooms() async {
    if (currentUserId == null) return [];
    final rows = await supabase
        .from('room_members')
        .select('rooms(*, room_members(count))')
        .eq('user_id', _uid);
    return (rows as List).map((item) {
      final room = Map<String, dynamic>.from(item['rooms']);
      final count = room['room_members'];
      room['member_count'] = count is List && count.isNotEmpty
          ? count.first['count'] ?? 0
          : 0;
      return TravelRoom.fromJson(room);
    }).toList();
  }

  Future<TravelRoom> getRoom(String roomId) async {
    final row = await supabase
        .from('rooms').select('*, room_members(count)').eq('id', roomId).single();
    final data = Map<String, dynamic>.from(row);

    final count = data['room_members'];
    data['member_count'] = count is List && count.isNotEmpty
        ? count.first['count'] ?? 0 : 0;
    return TravelRoom.fromJson(data);
  }

  Future<TravelRoom> createRoom({
    required String name,
    required String inviteCode,
    required int tripDays,
    required bool placeRecommendationEnabled,
  }) async {
    final result = await supabase.rpc('create_travel_room', params: {
      'p_name': name.trim(),
      'p_invite_code': inviteCode,
      'p_trip_days': tripDays,
      'p_place_recommendation_enabled': placeRecommendationEnabled,
    });
    return TravelRoom.fromJson(Map<String, dynamic>.from(result));
  }

  Future<TravelRoom?> joinRoom(String inviteCode) async {
    final result = await supabase.rpc('join_room_by_code', params: {
      'p_invite_code': inviteCode.trim().toUpperCase(),
    });
    if (result == null) return null;
    return TravelRoom.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> renameRoom(String roomId, String name) async =>
      supabase.rpc('rename_room', params: {'p_room_id': roomId, 'p_name': name.trim()});

  Future<void> leaveRoom(String roomId) async =>
      supabase.rpc('leave_room', params: {'p_room_id': roomId});

  Future<void> transferOwnership(String roomId, String newOwnerId) async =>
      supabase.rpc('transfer_room_ownership', params: {
        'p_room_id': roomId, 'p_new_owner_id': newOwnerId});

  Future<void> updateRoom(TravelRoom room) async =>
      supabase.from('rooms').update(room.toJson()).eq('id', room.id);

  Future<List<RoomMember>> getMembers(String roomId) async {
    final rows = await supabase.from('room_members')
        .select('*, profiles(nickname, avatar_url)')
        .eq('room_id', roomId).order('joined_at');
    final result = <RoomMember>[];
    for (final raw in rows as List) {
      final data = Map<String, dynamic>.from(raw);
      result.add(RoomMember.fromJson(data));
    }
    return result;
  }

  Future<DepartureInfo?> getDepartureInfo(String roomId) async {
    if (currentUserId == null) return null;
    final row = await supabase.from('room_members')
        .select('nickname, transport, address, lat, lng')
        .eq('room_id', roomId).eq('user_id', _uid).maybeSingle();
    if (row == null || row['address'] == null) return null;
    return DepartureInfo.fromJson({...row, 'room_id': roomId, 'user_id': _uid});
  }

  Future<void> saveDepartureInfo(DepartureInfo info) async {
    final room = await getRoom(info.roomId);
    if (!room.isScheduleFinalized) throw '여행 일정이 확정된 후 입력할 수 있습니다.';
    await supabase.from('room_members').update(info.toJson())
        .eq('room_id', info.roomId).eq('user_id', _uid);
  }

  // Midpoint recommendation ---------------------------------------------------
  /// 참가자들의 출발 정보를 바탕으로 만나기 좋은 동네 3곳을 추천받는다.
  /// 서버(Edge Function)에서 캐시가 있으면 그대로 반환하고, 없거나 멤버 수가
  /// 바뀌었으면 새로 계산한다. [forceRefresh]가 true면 캐시를 무시하고 재계산.
  Future<List<MidpointRecommendation>> getMidpointRecommendations(
    String roomId, {
    bool forceRefresh = false,
  }) async {
    final res = await supabase.functions.invoke(
      'calculate-midpoint',
      body: {'room_id': roomId, 'force_refresh': forceRefresh},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw data['error'].toString();
    }
    final list = (data as Map)['recommendations'] as List<dynamic>? ?? [];
    return list
        .map((e) => MidpointRecommendation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // Nearby place recommendations ---------------------------------------------
  /// "만나기 좋은 동네 추천"에서 특정 동네를 골랐을 때, 그 좌표 기준으로
  /// 실제 음식점/카페/놀거리를 추천받는다. 아직 방에 저장된 장소가 아니라
  /// "추가하기"를 눌러야 places 테이블에 들어간다.
  Future<List<PlaceSuggestion>> getNearbyPlaceRecommendations({
    required double lat,
    required double lng,
    int radiusMeters = 1500,
  }) async {
    final res = await supabase.functions.invoke(
      'recommend-places',
      body: {'lat': lat, 'lng': lng, 'radius_m': radiusMeters},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw data['error'].toString();
    }
    final list = (data as Map)['places'] as List<dynamic>? ?? [];
    return list
        .map((e) => PlaceSuggestion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // AI course generation -------------------------------------------------------
  /// 방에 저장된 장소들 + 여행 일수 + 하루 식사 횟수 + 참가자 이동수단을
  /// 고려해서 실제로 소화 가능한 일자별 동선을 서버(Edge Function)에서 계산한다.
  /// 반환된 코스는 아직 저장 전이므로, 사용자가 확인 후 [addCourse]로 저장해야 한다.
  Future<CourseItem> generateOptimalCourse(
    String roomId, {
    int mealsPerDay = 2,
  }) async {
    final res = await supabase.functions.invoke(
      'generate-course',
      body: {'room_id': roomId, 'meals_per_day': mealsPerDay},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw data['error'].toString();
    }
    return CourseItem.fromJson(Map<String, dynamic>.from((data as Map)['course']));
  }

  // Availability and final schedule ----------------------------------------
  Future<void> saveAvailability(String roomId, List<DateTime> dates) async {
    await supabase.from('date_availabilities').upsert({
      'room_id': roomId,
      'user_id': _uid,
      'available_dates': dates.map(_date).toList(),
      'submitted': true,
      'submitted_at': DateTime.now().toIso8601String(),
    }, onConflict: 'room_id,user_id');
    await supabase.rpc('recalculate_schedule_candidates',
        params: {'p_room_id': roomId});
  }

  Future<List<DateAvailability>> getAllAvailabilities(String roomId) async {
    final rows = await supabase.from('date_availabilities')
        .select('user_id, available_dates, submitted, profiles(nickname)')
        .eq('room_id', roomId);
    return (rows as List).map((e) => DateAvailability.fromJson(e)).toList();
  }

  Future<List<ScheduleCandidate>> getScheduleCandidates(String roomId) async {
    final rows = await supabase.rpc('get_schedule_candidates',
        params: {'p_room_id': roomId});
    return (rows as List)
        .map((e) => ScheduleCandidate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> approveCandidate(String roomId, String candidateId, bool approved) =>
      supabase.rpc('respond_schedule_candidate', params: {
        'p_room_id': roomId, 'p_candidate_id': candidateId, 'p_approved': approved});

  Future<void> voteCandidate(String roomId, String candidateId) =>
      supabase.rpc('vote_schedule_candidate', params: {
        'p_room_id': roomId, 'p_candidate_id': candidateId});

  // Friends and room invitations -------------------------------------------
  Future<List<UserProfile>> getFriends() async {
    final rows = await supabase.rpc('get_my_friends');
    return (rows as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<UserProfile?> findUserByEmail(String email) async {
    final row = await supabase.rpc('find_profile_by_email',
        params: {'p_email': email.trim().toLowerCase()});
    if (row == null || row is List && row.isEmpty) return null;
    final data = row is List ? row.first : row;
    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> sendFriendRequest(String profileId) =>
      supabase.rpc('send_friend_request', params: {'p_recipient_id': profileId});

  Future<List<Map<String, dynamic>>> getFriendRequests() async =>
      List<Map<String, dynamic>>.from(await supabase.rpc('get_friend_requests'));

  Future<void> respondFriendRequest(String requestId, bool accept) =>
      supabase.rpc('respond_friend_request', params: {
        'p_request_id': requestId, 'p_accept': accept});

  Future<void> removeFriend(String profileId) =>
      supabase.rpc('remove_friend', params: {'p_friend_id': profileId});

  Future<void> inviteFriendToRoom(String roomId, String friendId) =>
      supabase.rpc('invite_friend_to_room', params: {
        'p_room_id': roomId, 'p_invitee_id': friendId});

  Future<List<Map<String, dynamic>>> getRoomInvitations() async =>
      List<Map<String, dynamic>>.from(await supabase.rpc('get_room_invitations'));

  Future<void> respondRoomInvitation(String invitationId, bool accept) =>
      supabase.rpc('respond_room_invitation', params: {
        'p_invitation_id': invitationId, 'p_accept': accept});

  // Personal schedules ------------------------------------------------------
  Future<List<PersonalSchedule>> getPersonalSchedules(DateTime from, DateTime to) async {
    final rows = await supabase.from('personal_schedules').select()
        .gte('schedule_date', _date(from)).lte('schedule_date', _date(to))
        .order('schedule_date').order('schedule_time');
    return (rows as List).map((e) => PersonalSchedule.fromJson(e)).toList();
  }

  Future<void> savePersonalSchedule(PersonalSchedule item) async {
    final payload = {
      'owner_id': _uid,
      'title': item.title.trim(),
      'schedule_date': _date(item.scheduleDate),
      'schedule_time': item.isAllDay ? null : item.scheduleTime,
      'is_all_day': item.isAllDay,
      'memo': item.memo,
    };
    if (item.id.isEmpty) {
      await supabase.from('personal_schedules').insert(payload);
    } else {
      await supabase.from('personal_schedules').update(payload).eq('id', item.id);
    }
  }

  Future<void> deletePersonalSchedule(String id) =>
      supabase.from('personal_schedules').delete().eq('id', id);

  // Date-centred record albums ---------------------------------------------
  Future<List<RecordAlbum>> getAlbums({DateTime? from, DateTime? to}) async {
    if (currentUserId == null) return [];
    final myRooms = await supabase.from('room_members').select('room_id').eq('user_id', _uid);
    final roomIds = (myRooms as List).map((e) => e['room_id'].toString()).toList();

    var query = supabase.from('record_albums').select('* , profiles!record_albums_owner_id_fkey(nickname, avatar_url)');
    if (roomIds.isEmpty) {
      query = query.filter('room_id', 'is', null).eq('owner_id', _uid);
    } else {
      final roomIdList = roomIds.join(',');
      query = query.or('room_id.in.($roomIdList),and(room_id.is.null,owner_id.eq.$_uid)');
    }
    if (from != null) query = query.gte('record_date', _date(from));
    if (to != null) query = query.lte('record_date', _date(to));
    final rows = await query.order('record_date', ascending: false);
    final result = <RecordAlbum>[];
    for (final raw in rows as List) {
      final data = Map<String, dynamic>.from(raw);
      final albumId = data['id'];

      final profile = data['profiles'];
      data['owner_name'] = profile?['nickname'];
      data['owner_avatar'] = profile?['avatar_url'];

      final coverPath = data['cover_url'] as String?;
      if (coverPath != null && coverPath.isNotEmpty) {
        try {
          data['cover_url'] = await supabase.storage.from('record-media')
              .createSignedUrl(coverPath, 3600);
        } catch (_) {
          data['cover_url'] = null;
        }
      }

      final likeRows = await supabase
          .from('album_likes')
          .select('user_id')
          .eq('album_id', albumId);
      final commentRows = await supabase
          .from('album_comments')
          .select('id')
          .eq('album_id', albumId);

      data['like_count'] = (likeRows as List).length;
      data['comment_count'] = (commentRows as List).length;
      data['is_liked'] = currentUserId != null &&
          likeRows.any((r) => r['user_id'] == currentUserId);

      result.add(RecordAlbum.fromJson(data));
    }
    return result;
  }

  Future<RecordAlbum> getAlbum(String albumId) async {
    final raw = await supabase
        .from('record_albums')
        .select('* , profiles!record_albums_owner_id_fkey(nickname, avatar_url)')
        .eq('id', albumId)
        .single();
    final data = Map<String, dynamic>.from(raw);

    final profile = data['profiles'];
    data['owner_name'] = profile?['nickname'];
    data['owner_avatar'] = profile?['avatar_url'];

    final coverPath = data['cover_url'] as String?;
    if (coverPath != null && coverPath.isNotEmpty) {
      try {
        data['cover_url'] = await supabase.storage.from('record-media')
            .createSignedUrl(coverPath, 3600);
      } catch (_) {
        data['cover_url'] = null;
      }
    }

    final likeRows = await supabase
        .from('album_likes')
        .select('user_id')
        .eq('album_id', albumId);
    final commentRows = await supabase
        .from('album_comments')
        .select('id')
        .eq('album_id', albumId);

    data['like_count'] = (likeRows as List).length;
    data['comment_count'] = (commentRows as List).length;
    data['is_liked'] = currentUserId != null &&
        likeRows.any((r) => r['user_id'] == currentUserId);

    return RecordAlbum.fromJson(data);
  }

  Future<List<RecordAlbum>> getMyAlbums ({
    DateTime? from, 
    DateTime? to, 
  }) async {
    var query = supabase
      .from('record_albums')
      .select('* , profiles!record_albums_owner_id_fkey(nickname, avatar_url)')
      .eq('owner_id', _uid);

    if (from != null) {
      query = query.gte('record_date', _date(from));
    }
    if (to != null) {
      query = query.lte('record_date', _date(to));
    }
    final rows = await query.order('record_date', ascending: false);

    final result = <RecordAlbum>[];
    for (final raw in rows as List) {
      final data = Map<String, dynamic>.from(raw);
      final albumId = data['id'];

      final profile = data['profiles'];
      data['owner_name'] = profile?['nickname'];
      data['owner_avatar'] = profile?['avatar_url'];

      final coverPath = data['cover_url'] as String?;
      if (coverPath != null && coverPath.isNotEmpty) {
        try {
          data['cover_url'] = await supabase.storage.from('record-media')
              .createSignedUrl(coverPath, 3600);
        } catch (_) {
          data['cover_url'] = null;
        }
      }

      final likeRows = await supabase
          .from('album_likes')
          .select('user_id')
          .eq('album_id', albumId);
      final commentRows = await supabase
          .from('album_comments')
          .select('id')
          .eq('album_id', albumId);

      data['like_count'] = (likeRows as List).length;
      data['comment_count'] = (commentRows as List).length;
      data['is_liked'] = likeRows.any((r) => r['user_id'] == _uid);

      result.add(RecordAlbum.fromJson(data));
    }

    debugPrint('현재 UID: $_uid');
    debugPrint('조회 결과: ${result.length}건');

    return result;
  }

  Future<RecordAlbum> createAlbum({required DateTime date, required String title,
    required RecordVisibility visibility, String? roomId}) async {
    final row = await supabase.from('record_albums').insert({
      'owner_id': _uid, 'record_date': _date(date), 'title': title.trim(),
      'visibility': visibility.name, 'room_id': roomId,
    }).select().single();
    return RecordAlbum.fromJson(row);
  }

  Future<void> updateAlbum({
  required String albumId,
  required DateTime date,
  required String title,
  required RecordVisibility visibility,
  String? roomId,
}) async {
  await supabase.from('record_albums').update({
    'record_date': _date(date),
    'title': title.trim(),
    'visibility': visibility.name,
    'room_id': roomId,
  }).eq('id', albumId);
}

Future<void> clearAlbumEntries(String albumId) async {
  debugPrint('삭제 시작: $albumId');

  final result = await supabase
      .from('record_entries')
      .delete()
      .eq('album_id', albumId)
      .select();

  debugPrint('삭제 결과: $result');
}

  Future<List<RecordEntry>> getAlbumEntries(String albumId) async {
    final rows = await supabase.from('record_entries')
        .select('*, record_photos(*)').eq('album_id', albumId).order('order_index');
    final result = <RecordEntry>[];
    for (final raw in rows as List) {
      final data = Map<String, dynamic>.from(raw);
      final photos = List<Map<String,dynamic>>.from(data['record_photos'] ?? const []);
      for (final photo in photos) {
        photo['url'] = await supabase.storage.from('record-media')
            .createSignedUrl(photo['storage_path'].toString(), 3600);
      }
      data['record_photos'] = photos;
      result.add(RecordEntry.fromJson(data));
    }
    return result;
  }

  Future<String> addAlbumEntry({required String albumId, required String placeName,
    String? address, String? visitTime, String? note, required int orderIndex}) async {
    final row = await supabase.from('record_entries').insert({
      'album_id': albumId, 'place_name': placeName.trim(), 'address': address,
      'visit_time': visitTime, 'note': note, 'order_index': orderIndex,
    }).select('id').single();
    return row['id'].toString();
  }

  Future<String> uploadRecordPhoto({required String albumId, required String entryId,
    required Uint8List bytes, required int orderIndex, required bool isCover,
    String extension = 'jpg'}) async {
    final path = '$_uid/$albumId/$entryId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await supabase.storage.from('record-media').uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '3600'));
    await supabase.from('record_photos').insert({
      'album_id': albumId, 'entry_id': entryId, 'owner_id': _uid,
      'storage_path': path, 'url': null, 'order_index': orderIndex, 'is_cover': isCover,
    });
    if (isCover) {
      await supabase.from('record_albums').update({'cover_url': path}).eq('id', albumId);
    }
    return path;
  }

  Future<void> deleteAlbum(String albumId) async {
    // storage.objects는 SQL로 직접 지울 수 없으므로, 먼저 Storage API로
    // 이 앨범에 속한 파일들을 지우고 나서 DB 행 삭제 RPC를 호출한다.
    final photoRows = await supabase
        .from('record_photos')
        .select('storage_path')
        .eq('album_id', albumId);
    final paths = (photoRows as List)
        .map((r) => r['storage_path']?.toString())
        .whereType<String>()
        .toList();

    if (paths.isNotEmpty) {
      await supabase.storage.from('record-media').remove(paths);
    }

    // p_album_id로 삭제되는 DB 함수는 이제 storage.objects는 건드리지 않고
    // record_albums/record_entries/record_photos/album_likes/album_comments
    // 등 앱 테이블만 지우도록 서버 쪽 함수도 함께 수정해야 한다.
    await supabase.rpc('delete_record_album', params: {'p_album_id': albumId});
  }

  Future<List<Map<String,dynamic>>> getAlbumComments(String albumId) async =>
      List<Map<String,dynamic>>.from(await supabase.from('album_comments')
          .select('*, profiles(nickname, avatar_url)').eq('album_id', albumId).order('created_at'));

  Future<void> addAlbumComment(String albumId, String content, {String? albumOwnerId, String? albumTitle}) async {
    await supabase.from('album_comments').insert({'album_id': albumId, 'user_id': _uid, 'content': content.trim()});
    // 알림 생성은 부가 기능이므로, 여기서 실패해도 댓글 등록 자체는 성공한 것으로 처리한다.
    if (albumOwnerId != null) {
      try {
        final me = await getMyProfile();
        await _createNotification(
          recipientId: albumOwnerId,
          category: 'comment',
          eventType: 'album_comment',
          title: '새 댓글',
          body: '${me.nickname}님이 "${albumTitle ?? '기록'}"에 댓글을 남겼습니다.',
          data: {'album_id': albumId},
        );
      } catch (e) {
        debugPrint('알림 생성 실패(무시하고 진행): $e');
      }
    }
  }

  /// 본인이 작성한 댓글만 삭제됩니다 (user_id 조건으로 이중 확인).
  Future<void> deleteAlbumComment(String commentId) =>
      supabase.from('album_comments').delete()
          .eq('id', commentId).eq('user_id', _uid);

  /// 좋아요 토글. liked: true면 좋아요를 누른 상태, false면 취소된 상태.
  /// likeCount: 로컬에서 +1/-1로 임의 계산하지 않고, 처리 직후 서버에 실제로
  /// 남아있는 행 개수를 다시 세어 반환한다. 화면 숫자가 서버와 어긋나는 것을
  /// 막기 위함이다 (연타, 지연 응답, 오래된 로컬 상태 등으로 인한 불일치 방지).
  Future<({bool liked, int likeCount})> toggleAlbumLike(
    String albumId, {
    String? albumOwnerId,
    String? albumTitle,
  }) async {
    final existing = await supabase
        .from('album_likes')
        .select('album_id')
        .eq('album_id', albumId)
        .eq('user_id', _uid)
        .maybeSingle();

    bool liked;
    if (existing == null) {
      await supabase.from('album_likes').insert({
        'album_id': albumId,
        'user_id': _uid,
      });
      liked = true;
      // 알림 생성은 부가 기능이므로, 여기서 실패해도 좋아요 자체는 성공한 것으로 처리한다.
      if (albumOwnerId != null) {
        try {
          final me = await getMyProfile();
          await _createNotification(
            recipientId: albumOwnerId,
            category: 'like',
            eventType: 'album_like',
            title: '새 좋아요',
            body: '${me.nickname}님이 "${albumTitle ?? '기록'}"을 좋아합니다.',
            data: {'album_id': albumId},
          );
        } catch (e) {
          debugPrint('알림 생성 실패(무시하고 진행): $e');
        }
      }
    } else {
      final deleted = await supabase
          .from('album_likes')
          .delete()
          .eq('album_id', albumId)
          .eq('user_id', _uid)
          .select();
      debugPrint('좋아요 삭제된 행: $deleted');
      liked = false;
    }

    final likeRows = await supabase
        .from('album_likes')
        .select('user_id')
        .eq('album_id', albumId);
    final likeCount = (likeRows as List).length;

    return (liked: liked, likeCount: likeCount);
  }

  /// 특정 앨범에 내가 좋아요를 눌렀는지 단건 확인 (목록이 아니라 상세 화면 등에서 사용).
  Future<bool> isAlbumLikedByMe(String albumId) async {
    if (currentUserId == null) return false;
    final row = await supabase.from('album_likes').select('album_id')
        .eq('album_id', albumId).eq('user_id', _uid).maybeSingle();
    return row != null;
  }

  Future<void> _createNotification({
    required String recipientId,
    required String category,
    required String eventType,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (recipientId == _uid) return; // 본인 게시물에 본인이 반응한 경우는 알림 생략
    await supabase.from('notifications').insert({
      'recipient_id': recipientId,
      'category': category,
      'event_type': eventType,
      'title': title,
      'body': body,
      'data': data,
    });
  }

  // Notifications/preferences ----------------------------------------------
  Future<List<Map<String, dynamic>>> getNotifications() async =>
      List<Map<String, dynamic>>.from(await supabase.from('notifications')
          .select().eq('recipient_id', _uid).order('created_at', ascending: false).limit(100));

  Future<void> markNotificationRead(String id) =>
      supabase.from('notifications').update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', id).eq('recipient_id', _uid);

  Future<void> markAllNotificationsRead() =>
      supabase.from('notifications').update({'read_at': DateTime.now().toIso8601String()})
          .eq('recipient_id', _uid).filter('read_at', 'is', null);

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final row = await supabase.from('notification_preferences')
        .select().eq('user_id', _uid).maybeSingle();
    return row ?? {'user_id': _uid, 'push_enabled': true, 'email_enabled': true};
  }

  Future<void> saveNotificationPreferences(Map<String, dynamic> values) =>
      supabase.from('notification_preferences').upsert({'user_id': _uid, ...values});

  // Legacy place/course/record methods -------------------------------------
  /// 카카오 로컬 검색을 대신 호출해주는 Edge Function을 통해 장소를 검색한다.
  /// API 키는 서버(Supabase Secrets)에만 있고 클라이언트엔 노출되지 않는다.
  Future<List<dynamic>> searchPlaces(String query) async {
    final res = await supabase.functions.invoke(
      'kakao-place-search',
      body: {'query': query},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw data['error'].toString();
    }
    return (data as Map)['documents'] as List<dynamic>? ?? [];
  }

  /// get_places RPC를 통해 투표수(votes)와 내 투표 여부(has_my_vote)까지
  /// 함께 가져온다. places 테이블을 직접 select하면 이 값들을 알 수 없다.
  Future<List<PlaceItem>> getPlaces(String roomId) async {
    final rows = await supabase.rpc('get_places', params: {'p_room_id': roomId});
    return (rows as List).map((e) => PlaceItem.fromJson(e)).toList();
  }
  /// 삽입된 행을 그대로 반환한다 (id 포함). 화면에서 방금 추가한 장소를
  /// 바로 사용해야 하는 경우(예: 경로 직접 만들기에서 새 장소를 추가하자마자
  /// 그 날짜에 바로 배치)를 위해 id가 필요하기 때문이다.
  /// place.insertJson()을 사용해 places 테이블에 실제로 존재하는
  /// 컬럼만 보낸다 (address/votes는 컬럼이 아니므로 제외).
  Future<PlaceItem> addPlace(String roomId, PlaceItem place) async {
    final row = await supabase
        .from('places')
        .insert({...place.insertJson(), 'room_id': roomId, 'added_by': _uid})
        .select()
        .single();
    return PlaceItem.fromJson(row);
  }
  Future<void> deletePlace(String placeId) async =>
      supabase.from('places').delete().eq('id', placeId);
  /// 장소 투표를 토글한다 (이미 투표했으면 취소). 반환값은 투표 후 상태.
  Future<bool> votePlace(String placeId) async =>
      await supabase.rpc('vote_place', params: {'p_place_id': placeId}) as bool;

  Future<List<CourseItem>> getCourses(String roomId) async {
    final rows = await supabase.rpc('get_courses', params: {'p_room_id': roomId});
    return (rows as List).map((e) => CourseItem.fromJson(e)).toList();
  }
  Future<void> addCourse(String roomId, CourseItem course) async =>
      supabase.from('courses').insert({...course.toJson(), 'room_id': roomId});
  Future<void> deleteCourse(String courseId) async =>
      supabase.from('courses').delete().eq('id', courseId);
  /// 코스 투표를 토글한다 (이미 투표했으면 취소). 반환값은 투표 후 상태.
  Future<bool> voteCourse(String courseId) async =>
      await supabase.rpc('vote_course', params: {'p_course_id': courseId}) as bool;
  Future<List<RecordItem>> getRecords({String? roomId}) async {
    try {
      var q = supabase.from('records').select('*, profiles(nickname, avatar_url), comments:record_comments(count)');
      if (roomId != null) q = q.eq('room_id', roomId);
      final rows = await q.order('created_at', ascending: false);
      return (rows as List).map((e) => RecordItem.fromJson(e)).toList();
    } catch (e) { debugPrint('legacy records: $e'); return []; }
  }
  Future<void> addRecord(RecordItem record) => supabase.from('records').insert(record.toJson());
  Future<List<RecordComment>> getComments(String recordId) async {
    final rows = await supabase.from('record_comments').select('*, profiles(nickname, avatar_url)')
        .eq('record_id', recordId).order('created_at');
    return (rows as List).map((e) => RecordComment.fromJson(e)).toList();
  }
  Future<void> addComment(String recordId, String content) => supabase.from('record_comments')
      .insert({'record_id': recordId, 'user_id': _uid, 'content': content.trim()});
}