from route_api import (
    get_car_travel_time
)


# =========================
# 사용자 중간 좌표 계산
# =========================

def get_middle_point(users):

    if not users:
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

    if middle_lat is None:

        return []

    times = []

    # =========================
    # 실제 자동차 이동시간 계산
    # =========================

    for user in users:

        travel_time = (

            get_car_travel_time(

                user["lat"],
                user["lng"],

                middle_lat,
                middle_lng
            )
        )

        if travel_time is not None:

            times.append(
                travel_time
            )

    # =========================
    # 이동시간 계산 실패
    # =========================

    if not times:

        avg_time = 0
        max_time = 0

    else:

        avg_time = int(

            sum(times)
            / len(times)
        )

        max_time = max(times)

    return [

        {
            "name":
            "중간 약속 장소",

            "lat":
            middle_lat,

            "lng":
            middle_lng,

            "address":
            "중간 위치 기반 추천",

            "avg_time":
            avg_time,

            "max_time":
            max_time
        }

    ]