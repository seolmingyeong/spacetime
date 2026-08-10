import 'dart:math';

import '../models/models.dart';
import 'supabase_repository.dart';

class GroupScoreResult {
  final double score;
  final int avgMinutes;
  final int maxMinutes;
  final int balanceMinutes;
  final List<UserTimeInfo> userTimes;

  GroupScoreResult({
    required this.score,
    required this.avgMinutes,
    required this.maxMinutes,
    required this.balanceMinutes,
    required this.userTimes,
  });

  String get label {
    if (score < 50) return '매우 공평함';
    if (score < 100) return '공평함';
    if (score < 200) return '보통';
    return '불균형';
  }
}

class UserTimeInfo {
  final String nickname;
  final int minutes;

  UserTimeInfo(this.nickname, this.minutes);
}

class GroupScoringService {
  static final SupabaseRepository _repository =
      SupabaseRepository();

  /// 두 좌표 사이의 직선거리를 km 단위로 계산한다.
  static double _calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;

    final deltaLat = (lat2 - lat1) * pi / 180;
    final deltaLng = (lng2 - lng1) * pi / 180;

    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLng / 2) *
            sin(deltaLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Kakao Mobility 호출이 실패했을 때 사용할
  /// 직선거리 기반 예상 이동시간.
  ///
  /// 실제 도로 이동시간을 알 수 없으므로
  /// 평균 자동차 속도를 기준으로 대략적인 시간을 계산한다.
  static int _estimateDriveTimeMinutes(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    final distanceKm = _calculateDistanceKm(
      originLat,
      originLng,
      destLat,
      destLng,
    );

    // 도심 주행을 고려한 보수적인 평균 속도
    const averageSpeedKmh = 30.0;

    final minutes =
        (distanceKm / averageSpeedKmh) * 60;

    return max(1, minutes.round());
  }

  /// 각 멤버의 출발지에서 후보 장소까지의
  /// 실제 자동차 이동시간을 이용해 그룹 점수를 계산한다.
  ///
  /// Kakao Mobility 호출에 실패한 멤버는
  /// 직선거리 기반 예상시간으로 fallback한다.
  static Future<GroupScoreResult?> evaluatePlace(
    List<RoomMember> members,
    double targetLat,
    double targetLng,
  ) async {
    if (members.isEmpty) return null;

    final futures = members.map((member) async {
      final departure = member.departure;

      if (departure == null) {
        return null;
      }

      int minutes;

      try {
        final driveTime =
            await _repository.getDriveTime(
          originLat: departure.lat,
          originLng: departure.lng,
          destLat: targetLat,
          destLng: targetLng,
        );

        if (driveTime != null) {
          // Kakao Mobility 성공
          minutes = driveTime;
        } else {
          // Kakao Mobility 실패 → 거리 기반 fallback
          minutes = _estimateDriveTimeMinutes(
            departure.lat,
            departure.lng,
            targetLat,
            targetLng,
          );
        }
      } catch (_) {
        // API 호출 자체가 실패한 경우에도
        // 거리 기반 예상시간으로 계산을 계속한다.
        minutes = _estimateDriveTimeMinutes(
          departure.lat,
          departure.lng,
          targetLat,
          targetLng,
        );
      }

      return UserTimeInfo(
        member.nickname,
        minutes,
      );
    }).toList();

    final results = await Future.wait(futures);

    final userTimes = results
        .whereType<UserTimeInfo>()
        .toList();

    if (userTimes.isEmpty) return null;

    final times = userTimes
        .map((user) => user.minutes)
        .toList();

    final maxTime = times.reduce(max);
    final minTime = times.reduce(min);

    final avgTime =
        times.reduce((a, b) => a + b) / times.length;

    final balance = maxTime - minTime;

    // 친구 코드의 그룹 공평성 점수 공식
    // 낮을수록 그룹 전체의 이동 부담이 적고 공평하다.
    final score =
        (balance * 5.0) +
        (avgTime * 0.8) +
        (maxTime * 1.2);

    return GroupScoreResult(
      score: score,
      avgMinutes: avgTime.round(),
      maxMinutes: maxTime,
      balanceMinutes: balance,
      userTimes: userTimes,
    );
  }
}