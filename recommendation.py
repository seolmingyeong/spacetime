from route_api import (

    get_car_travel_time,

    get_walk_travel_time,

    get_transit_travel_time
)

from place_api import (
    search_places
)


# =========================
# 이동시간 계산
# =========================

def get_travel_time(

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

    # 기본값

    return get_car_travel_time(

        user["lat"],
        user["lng"],

        lat,
        lng
    )


# =========================
# 추천 장소 생성
# =========================

def recommend_places(users):

    # =========================
    # 후보 장소 수집
    # =========================

    all_places = []

    # =========================
    # 사용자 위치 수집
    # =========================

    points = []

    for user in users:

        points.append(

            (
                user["lat"],
                user["lng"]
            )
        )

    # =========================
    # 사용자 사이 중간 지점들 생성
    # =========================

    for i in range(len(users)):

        for j in range(i + 1, len(users)):

            lat1 = users[i]["lat"]
            lng1 = users[i]["lng"]

            lat2 = users[j]["lat"]
            lng2 = users[j]["lng"]

            # =========================
            # 경로 위 여러 지점 생성
            # =========================

            for ratio in [

                0.25,
                0.5,
                0.75
            ]:

                mid_lat = (

                    lat1
                    + (lat2 - lat1)
                    * ratio
                )

                mid_lng = (

                    lng1
                    + (lng2 - lng1)
                    * ratio
                )

                points.append(

                    (
                        mid_lat,
                        mid_lng
                    )
                )

    # =========================
    # 각 포인트 주변 장소 검색
    # =========================

    for lat, lng in points:

        places = search_places(

            lat,
            lng,

            "카페"
        )

        all_places.extend(
            places
        )

    # =========================
    # 중복 제거
    # =========================

    unique_places = []

    used_names = set()

    for place in all_places:

        name = place["name"]

        if name in used_names:

            continue

        used_names.add(name)

        unique_places.append(place)

    recommendations = []

    # =========================
    # 장소별 이동시간 계산
    # =========================

    for place in unique_places:

        lat = place["lat"]
        lng = place["lng"]

        times = []

        user_times = []

        valid = True

        for user in users:

            travel_time = get_travel_time(

                user,

                lat,
                lng
            )

            # =========================
            # 경로 계산 실패
            # =========================

            if travel_time is None:

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