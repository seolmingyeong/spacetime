from route_api import (
    compute_route_duration
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

    origin_place_id = (
        user.get(
            "place_id"
        )
    )

    destination_place_id = (
        place.get(
            "place_id"
        )
    )

    if not origin_place_id:

        return None

    if not destination_place_id:

        return None

    # =========================
    # 자동차
    # =========================

    if transport in [

        "자동차",
        "car",
        "drive"
    ]:

        return compute_route_duration(

            origin_place_id,

            destination_place_id,

            "DRIVE"
        )

    # =========================
    # 도보
    # =========================

    elif transport in [

        "도보",
        "walk",
        "walking"
    ]:

        return compute_route_duration(

            origin_place_id,

            destination_place_id,

            "WALK"
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

        return compute_route_duration(

            origin_place_id,

            destination_place_id,

            "TRANSIT"
        )

    return None



# =========================
# 후보 장소 수집
# =========================

def collect_candidate_places(users):

    candidate_places = []

    search_points = []

    for user in users:

        search_points.append(

            (
                user["lat"],
                user["lng"]
            )
        )

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

    for lat, lng in search_points:

        places = search_places(

            lat,
            lng,

            "카페"
        )

        candidate_places.extend(
            places
        )

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

    places = collect_candidate_places(
        users
    )

    recommendations = []

    for place in places:

        st.write(
            "평가 중:",
            place["name"]
        )

        times = []

        user_times = []

        for user in users:

            travel_time = get_real_travel_time(

                user,

                place
            )

            st.write(

                user["nickname"],

                user["transport"],

                travel_time
            )

            if travel_time is None:

                travel_time = 999

            times.append(
                travel_time
            )

            user_times.append({

                "nickname":
                user["nickname"],

                "travel_time":
                travel_time
            })

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

    return recommendations[:3]