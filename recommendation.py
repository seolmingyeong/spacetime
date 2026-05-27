from route_api import (

    get_car_travel_time,

    get_walk_travel_time,

    get_transit_travel_time
)

from place_api import (
    search_places
)

import streamlit as st


# =========================
# 실제 이동시간 계산
# =========================

def get_real_travel_time(

    user,

    place
):

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

        return get_car_travel_time(

            user["lat"],
            user["lng"],

            place["lat"],
            place["lng"]
        )

    # =========================
    # 도보
    # =========================

    elif transport in [

        "도보",
        "walk",
        "walking"
    ]:

        return get_walk_travel_time(

            user["lat"],
            user["lng"],

            place["lat"],
            place["lng"]
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

        return get_transit_travel_time(

            user["lat"],
            user["lng"],

            place["lat"],
            place["lng"]
        )

    return None


# =========================
# 후보 장소 수집
# =========================

def collect_candidate_places(users):

    candidate_places = []

    search_points = []

    # =========================
    # 사용자 위치
    # =========================

    for user in users:

        search_points.append(

            (
                user["lat"],
                user["lng"]
            )
        )

    # =========================
    # corridor 생성
    # =========================

    for i in range(len(users)):

        for j in range(i + 1, len(users)):

            lat1 = users[i]["lat"]
            lng1 = users[i]["lng"]

            lat2 = users[j]["lat"]
            lng2 = users[j]["lng"]

            for ratio in [

                0.25,
                0.5,
                0.75
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
    # 장소 검색
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

    return unique_places[:5]


# =========================
# 추천 장소 생성
# =========================

def recommend_places(users):

    st.write("recommend_places 진입")

    places = collect_candidate_places(
        users
    )

    st.write(
        "후보 장소 개수:",
        len(places)
    )

    recommendations = []

    for place in places:

        st.write(
            "현재 평가 장소:",
            place["name"]
        )

        times = []

        user_times = []

        for user in users:

            try:

                travel_time = get_real_travel_time(

                    user,

                    place
                )

            except Exception as e:

                st.write(
                    "ERROR:",
                    str(e)
                )

                travel_time = None

            # =========================
            # 경로 실패 패널티
            # =========================

            if travel_time is None:

                travel_time = 999

            # =========================
            # 너무 먼 경우 패널티
            # =========================

            transport = user.get(
                "transport",
                "자동차"
            )

            if transport == "도보":

                if travel_time > 45:

                    travel_time += 300

            elif transport == "대중교통":

                if travel_time > 100:

                    travel_time += 200

            elif transport == "자동차":

                if travel_time > 100:

                    travel_time += 100

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

        score = (
            balance_score
            + avg_score * 0.3
        )

        recommendations.append({

            "name":
            place["name"],

            "lat":
            place["lat"],

            "lng":
            place["lng"],

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

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    st.write(

        "최종 추천 개수:",

        len(recommendations)
    )

    return recommendations[:3]