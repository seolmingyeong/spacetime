from route_api import (
    get_car_travel_time
)

from place_api import (
    search_places
)


# =========================
# 평균 좌표 계산
# =========================

def get_middle_point(users):

    if len(users) == 0:

        return None, None

    avg_lat = sum(

        user["lat"]

        for user in users

    ) / len(users)

    avg_lng = sum(

        user["lng"]

        for user in users

    ) / len(users)

    return avg_lat, avg_lng


# =========================
# 추천 장소 생성
# =========================

def recommend_places(

    users,

    middle_lat,
    middle_lng
):

    # =========================
    # 중간지점 근처 카페 검색
    # =========================

    places = search_places(

        middle_lat,
        middle_lng,

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

        for user in users:

            travel_time = (

                get_car_travel_time(

                    user["lat"],
                    user["lng"],

                    lat,
                    lng
                )
            )

            if travel_time is None:

                continue

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
        # 계산 실패
        # =========================

        if len(times) == 0:

            continue

        avg_time = int(

            sum(times)
            / len(times)
        )

        max_time = max(times)

        score = (
            avg_time
            + max_time
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
            avg_time,

            "max_time":
            max_time,

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

    # =========================
    # 상위 3개 반환
    # =========================

    return recommendations[:3]