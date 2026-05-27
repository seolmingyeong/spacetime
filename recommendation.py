from route_api import (

    get_car_travel_time,

    get_walk_travel_time,

    get_transit_travel_time
)

from place_api import (
    search_places
)


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
# 후보 장소 수집
# =========================

def collect_candidate_places(users):

    candidate_places = []

    # =========================
    # 사용자 위치
    # =========================

    search_points = []

    for user in users:

        search_points.append(

            (
                user["lat"],
                user["lng"]
            )
        )

    # =========================
    # 사용자 사이 corridor 생성
    # =========================

    for i in range(len(users)):

        for j in range(i + 1, len(users)):

            lat1 = users[i]["lat"]
            lng1 = users[i]["lng"]

            lat2 = users[j]["lat"]
            lng2 = users[j]["lng"]

            # =========================
            # 중간 경로 포인트
            # =========================

            for ratio in [

                0.2,
                0.4,
                0.6,
                0.8
            ]:

                lat = (

                    lat1
                    + (lat2 - lat1)
                    * ratio
                )

                lng = (

                    lng1
                    + (lng2 - lng1)
                    * ratio
                )

                search_points.append(
                    (lat, lng)
                )

    # =========================
    # 각 포인트 주변 실제 장소 검색
    # =========================

    for lat, lng in search_points:

        places = search_places(

            lat,
            lng,

            "카페"
        )

        candidate_places.extend(
            places
        )

    # =========================
    # 중복 제거
    # =========================

    unique_places = []

    used_names = set()

    for place in candidate_places:

        name = place["name"]

        if name in used_names:

            continue

        used_names.add(name)

        unique_places.append(place)

    return unique_places


# =========================
# 추천 장소 생성
# =========================

def recommend_places(users):

    # =========================
    # 후보 장소 수집
    # =========================

    places = collect_candidate_places(
        users
    )

    recommendations = []

    # =========================
    # 장소별 실제 이동시간 평가
    # =========================

    for place in places:

        lat = place["lat"]
        lng = place["lng"]

        times = []

        user_times = []

        valid = True

        for user in users:

            travel_time = get_real_travel_time(

                user,

                lat,
                lng
            )

            # =========================
            # transit/walking 실패
            # =========================

            if travel_time is None:

                valid = False
                break

            # =========================
            # 현실적 최대 이동시간 제한
            # =========================

            transport = user.get(
                "transport",
                "자동차"
            )

            limit = 999

            if transport == "도보":

                limit = 45

            elif transport == "대중교통":

                limit = 100

            elif transport == "자동차":

                limit = 100

            # =========================
            # 너무 먼 경우 제외
            # =========================

            if travel_time > limit:

                valid = False
                break

            times.append(
                travel_time
            )

            user_times.append({

                "nickname":
                user["nickname"],

                "travel_time":
                travel_time
            })

        # =========================
        # 한 명이라도 실패 시 제외
        # =========================

        if not valid:

            continue

        # =========================
        # 시간 균형 score
        # =========================

        balance_score = (

            max(times)
            - min(times)
        )

        avg_score = (
            sum(times)
            / len(times)
        )

        # =========================
        # 최종 점수
        # =========================

        score = (
            balance_score
            + avg_score * 0.3
        )

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
            int(avg_score),

            "max_time":
            max(times),

            "score":
            score,

            "user_times":
            user_times
        })

    # =========================
    # 점수 기준 정렬
    # =========================

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    return recommendations[:3]
