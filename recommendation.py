from route_api import (
    get_travel_time
)

from place_api import (
    search_places
)

import streamlit as st


# =========================
# grid 생성
# =========================

def generate_grid_points(

    users,

    grid_size=8
):

    lats = [
        user["lat"]
        for user in users
    ]

    lngs = [
        user["lng"]
        for user in users
    ]

    min_lat = min(lats)
    max_lat = max(lats)

    min_lng = min(lngs)
    max_lng = max(lngs)

    # padding

    lat_padding = 0.03
    lng_padding = 0.03

    min_lat -= lat_padding
    max_lat += lat_padding

    min_lng -= lng_padding
    max_lng += lng_padding

    grid_points = []

    for i in range(grid_size):

        for j in range(grid_size):

            lat = (

                min_lat

                + (max_lat - min_lat)

                * i
                / (grid_size - 1)
            )

            lng = (

                min_lng

                + (max_lng - min_lng)

                * j
                / (grid_size - 1)
            )

            grid_points.append(
                (lat, lng)
            )

    return grid_points


# =========================
# grid 평가
# =========================

def evaluate_grid_point(

    users,

    lat,
    lng
):

    times = []

    for user in users:

        result = get_travel_time(

            user["lat"],
            user["lng"],

            lat,
            lng,

            user["transport"]
        )

        if result is None:

            return None

        minutes = result["minutes"]

        times.append(
            minutes
        )

    balance = (

        max(times)
        - min(times)
    )

    avg_time = (

        sum(times)
        / len(times)
    )

    max_time = max(times)

    # =========================
    # 불균형 제거
    # =========================

    if balance > 25:

        return None

    # =========================
    # 너무 먼 경우 제거
    # =========================

    if max_time > 70:

        return None

    # =========================
    # 점수 계산
    # =========================

    score = (

        balance * 3

        + avg_time * 0.5

        + max_time * 0.7
    )

    return {

        "lat":
        lat,

        "lng":
        lng,

        "score":
        score,

        "times":
        times,

        "avg_time":
        avg_time
    }


# =========================
# 시간 최적 지점 탐색
# =========================

def find_best_meeting_points(

    users
):

    st.subheader(
        "GRID SEARCH"
    )

    grid_points = generate_grid_points(
        users
    )

    best_points = []

    for idx, (lat, lng) in enumerate(grid_points):

        st.write(
            f"GRID {idx + 1}/{len(grid_points)}"
        )

        result = evaluate_grid_point(

            users,

            lat,
            lng
        )

        if result:

            best_points.append(
                result
            )

    best_points.sort(

        key=lambda x:
        x["score"]
    )

    st.write(
        f"유효 grid 수: {len(best_points)}"
    )

    return best_points[:10]


# =========================
# 후보 장소 수집
# =========================

def collect_candidate_places(

    users
):

    best_points = (

        find_best_meeting_points(
            users
        )
    )

    candidate_places = []

    for point in best_points:

        places = search_places(

            point["lat"],
            point["lng"],

            "카페"
        )

        candidate_places.extend(
            places
        )

    # =========================
    # 중복 제거
    # =========================

    unique_places = []

    used_place_ids = set()

    for place in candidate_places:

        place_id = place.get(
            "place_id"
        )

        if not place_id:
            continue

        if place_id in used_place_ids:
            continue

        used_place_ids.add(
            place_id
        )

        unique_places.append(
            place
        )

    st.write(
        f"후보 장소 수: {len(unique_places)}"
    )

    return unique_places[:50]


# =========================
# 최종 추천
# =========================

def recommend_places(

    users
):

    places = collect_candidate_places(
        users
    )

    recommendations = []

    for place in places:

        times = []

        user_times = []

        failed = False

        for user in users:

            result = get_travel_time(

                user["lat"],
                user["lng"],

                place["lat"],
                place["lng"],

                user["transport"]
            )

            if result is None:

                failed = True

                break

            minutes = result["minutes"]

            times.append(
                minutes
            )

            user_times.append({

                "nickname":
                user["nickname"],

                "travel_time":
                minutes
            })

        if failed:

            continue

        balance = (

            max(times)
            - min(times)
        )

        avg_time = (

            sum(times)
            / len(times)
        )

        max_time = max(times)

        if balance > 25:
            continue

        if max_time > 70:
            continue

        score = (

            balance * 3

            + avg_time * 0.5

            + max_time * 0.7
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
            round(avg_time),

            "max_time":
            max_time,

            "balance":
            balance,

            "score":
            round(score, 2),

            "user_times":
            user_times
        })

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    st.subheader(
        "FINAL RECOMMENDATIONS"
    )

    st.code(recommendations)

    return recommendations[:5]