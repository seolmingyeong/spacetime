```python
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
# 시간 균형 좌표 찾기
# =========================

def find_best_point(users):

    # =========================
    # 중심 좌표 계산
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

    step = 0.02

    for lat_offset in range(-5, 6):

        for lng_offset in range(-5, 6):

            candidate_points.append(

                (
                    center_lat
                    + lat_offset * step,

                    center_lng
                    + lng_offset * step
                )
            )

    # =========================
    # 최적 score 탐색
    # =========================

    best_score = float("inf")

    best_point = None

    for lat, lng in candidate_points:

        times = []

        valid = True

        for user in users:

            travel_time = get_travel_time(

                user,

                lat,
                lng
            )

            if travel_time is None:

                valid = False

                break

            times.append(
                travel_time
            )

        if not valid:

            continue

        # =========================
        # 시간 균형 score
        # =========================

        score = (

            max(times)
            - min(times)
        )

        # 평균도 조금 반영

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

    return best_point


# =========================
# 추천 장소 생성
# =========================

def recommend_places(

    users,

    middle_lat,
    middle_lng
):

    # =========================
    # 시간 균형 좌표 찾기
    # =========================

    best_point = find_best_point(
        users
    )

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

    # =========================
    # 장소별 이동시간 계산
    # =========================

    for place in places:

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

        if not valid:

            continue

        # =========================
        # 시간 균형 중심 score
        # =========================

        score = (

            max(times)
            - min(times)
        )

        # 평균시간도 조금 반영

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

    # =========================
    # score 기준 정렬
    # =========================

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    return recommendations[:3]
```
