import 'dart:math';
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
    if (score < 50) return '매우 균형';
    if (score < 100) return '균형';
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

  /// Kakao Mobility 호출에 실패했을 때 사용하는
  /// 직선거리 기반 예상 이동시간.
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

    // 평균 자동차 주행속도 30km/h 기준
    const averageSpeedKmh = 30.0;

    final minutes =
        (distanceKm / averageSpeedKmh) * 60;

    return max(1, minutes.round());
  }

  /// 각 멤버의 출발지에서 특정 장소까지의 이동시간을 계산하고
  /// 그룹 전체의 균형 점수를 계산한다.
  ///
  /// Kakao Mobility API를 우선 사용하고,
  /// API 호출에 실패하면 직선거리 기반 예상시간으로 fallback한다.
  static Future<GroupScoreResult?> evaluatePlace(
    List members,
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
          // Kakao Mobility 결과 사용
          minutes = driveTime;
        } else {
          // API 결과가 없으면 거리 기반 fallback
          minutes = _estimateDriveTimeMinutes(
            departure.lat,
            departure.lng,
            targetLat,
            targetLng,
          );
        }
      } catch (_) {
        // API 호출 자체가 실패해도
        // 거리 기반 예상시간으로 계속 계산한다.
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

    // 그룹 이동시간 균형 점수
    //
    // balance가 작을수록,
    // 평균 이동시간이 짧을수록,
    // 최대 이동시간이 짧을수록 점수가 낮아진다.
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