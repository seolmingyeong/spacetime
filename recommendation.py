from math import sqrt

from route_api import (

    get_car_travel_time,

    get_walk_travel_time,

    get_transit_travel_time
)

from place_api import (
    search_places
)


# =========================
# 이동수단별 평균 속도
# =========================

TRANSPORT_SPEED = {

    "도보": 4,
    "대중교통": 25,
    "자동차": 50
}


# =========================
# 직선거리 계산
# =========================

def calculate_distance(

    lat1,
    lng1,

    lat2,
    lng2
):

    return sqrt(

        (lat1 - lat2) ** 2
        +
        (lng1 - lng2) ** 2
    )


# =========================
# 빠른 예상시간 계산
# =========================

def estimate_time(

    user,

    lat,
    lng
):

    distance = calculate_distance(

        user["lat"],
        user["lng"],

        lat,
        lng
    )

    transport = user.get(
        "transport",
        "자동차"
    )

    speed = TRANSPORT_SPEED.get(
        transport,
        30
    )

    # 대충 km 비슷하게 보정

    distance_km = distance * 111

    time_hour = (
        distance_km
        / speed
    )

    return time_hour * 60


# =========================
# 실제 이동시간 계산
# =========================

def get_real_travel_time(

    user,

    lat,
    lng
):

    transport = str(

        user.get(
            "transport",
            "자동차"
        )

    ).strip().lower()

    # 자동차

    if transport in [

        "자동차",
        "car",
        "drive"
    ]:

        return get_car_travel_time(

            user["lat"],
            user["lng"],

            lat,
            lng
        )

    # 도보

    elif transport in [

        "도보",
        "walk",
        "walking"
    ]:

        return get_walk_travel_time(

            user["lat"],
            user["lng"],

            lat,
            lng
        )

    # 대중교통

    elif transport in [

        "대중교통",
        "transit",
        "bus",
        "subway"
    ]:

        return get_transit_travel_time(

            user["lat"],
            user["lng"],

            lat,
            lng
        )

    return None


# =========================
# 추천 장소 생성
# =========================

def recommend_places(users):

    # =========================
    # 중심 좌표
    # =========================

    center_lat = sum(

        user["lat"]

        for user in users

    ) / len(users)

    center_lng = sum(

        user["lng"]

        for user in users

    ) / len(users)

    # =========================
    # 후보 좌표 생성
    # =========================

    candidate_points = []

    step = 0.03

    for lat_offset in range(-4, 5):

        for lng_offset in range(-4, 5):

            lat = (
                center_lat
                + lat_offset * step
            )

            lng = (
                center_lng
                + lng_offset * step
            )

            candidate_points.append(
                (lat, lng)
            )

    # =========================
    # 빠른 탐색
    # =========================

    fast_scores = []

    for lat, lng in candidate_points:

        times = []

        valid = True

        for user in users:

            estimated = estimate_time(

                user,

                lat,
                lng
            )

            transport = user.get(
                "transport",
                "자동차"
            )

            # =========================
            # 이동수단별 현실적 제한
            # =========================

            limit = 999

            if transport == "도보":

                limit = 40

            elif transport == "대중교통":

                limit = 90

            elif transport == "자동차":

                limit = 90

            # =========================
            # 현실적으로 불가능한 후보 제거
            # =========================

            if estimated > limit:

                valid = False
                break

            times.append(
                estimated
            )

        # =========================
        # 탈락 후보 제거
        # =========================

        if not valid:

            continue


        score = (

            max(times)
            - min(times)
        )

        score += (
            sum(times)
            / len(times)
        ) * 0.2

        fast_scores.append({

            "lat": lat,
            "lng": lng,

            "score": score
        })

    # =========================
    # 상위 후보만 선택
    # =========================

    fast_scores.sort(

        key=lambda x:
        x["score"]
    )

    top_candidates = fast_scores[:8]

    # =========================
    # 실제 API 기반 정밀 평가
    # =========================

    best_point = None

    best_score = float("inf")

    for point in top_candidates:

        lat = point["lat"]
        lng = point["lng"]

        times = []

        valid = True

        for user in users:

            real_time = get_real_travel_time(

                user,

                lat,
                lng
            )

            if real_time is None:

                valid = False
                break

            times.append(
                real_time
            )

        if not valid:

            continue

        score = (

            max(times)
            - min(times)
        )

        score += (
            sum(times)
            / len(times)
        ) * 0.3

        if score < best_score:

            best_score = score

            best_point = (
                lat,
                lng
            )

    # =========================
    # 최적 좌표 실패
    # =========================

    if not best_point:

        return []

    best_lat, best_lng = best_point

    # =========================
    # 최적 지점 근처 장소 검색
    # =========================

    places = search_places(

        best_lat,
        best_lng,

        "카페"
    )

    recommendations = []

    for place in places:

        lat = place["lat"]
        lng = place["lng"]

        times = []

        user_times = []

        valid = True

        for user in users:

            real_time = get_real_travel_time(

                user,

                lat,
                lng
            )

            if real_time is None:

                valid = False
                break

            times.append(
                real_time
            )

            user_times.append({

                "nickname":
                user["nickname"],

                "travel_time":
                real_time
            })

        if not valid:

            continue

        score = (

            max(times)
            - min(times)
        )

        score += (
            sum(times)
            / len(times)
        ) * 0.3

        recommendations.append({

            "name":
            place["name"],

            "lat":
            lat,

            "lng":
            lng,

            "address":
            place["address"],

            "avg_time":
            int(

                sum(times)
                / len(times)
            ),

            "max_time":
            max(times),

            "score":
            score,

            "user_times":
            user_times
        })

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    return recommendations[:3]