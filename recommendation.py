from route_api import (

    get_car_travel_time,

    get_walk_travel_time,

    get_transit_travel_time
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
    # 중간지점 근처 장소 검색
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

        # =========================
        # 사용자별 이동시간 계산
        # =========================

        for user in users:

            transport = str(

                user.get(
                    "transport",
                    "자동차"
                )

            ).strip().lower()

            # =========================
            # 자동차
            # =========================

            if transport in [

                "자동차",
                "car",
                "drive"
            ]:

                travel_time = (

                    get_car_travel_time(

                        user["lat"],
                        user["lng"],

                        lat,
                        lng
                    )
                )

            # =========================
            # 도보
            # =========================

            elif transport in [

                "도보",
                "walk",
                "walking"
            ]:

                travel_time = (

                    get_walk_travel_time(

                        user["lat"],
                        user["lng"],

                        lat,
                        lng
                    )
                )

            # =========================
            # 대중교통
            # =========================

            elif transport in [

                "대중교통",
                "transit",
                "bus",
                "subway"
            ]:

                travel_time = (

                    get_transit_travel_time(

                        user["lat"],
                        user["lng"],

                        lat,
                        lng
                    )
                )

            # =========================
            # 기본값
            # =========================

            else:

                travel_time = (

                    get_car_travel_time(

                        user["lat"],
                        user["lng"],

                        lat,
                        lng
                    )
                )

            # =========================
            # 계산 실패
            # =========================

            if travel_time is None:

                continue

            # =========================
            # 이동시간 저장
            # =========================

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

        # =========================
        # 평균/최대 시간 계산
        # =========================

        avg_time = int(

            sum(times)
            / len(times)
        )

        max_time = max(times)

        # =========================
        # 추천 점수
        # =========================

        score = (
            avg_time
            + max_time
        )

        # =========================
        # 추천 장소 저장
        # =========================

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