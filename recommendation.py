from route_api import (
    get_travel_time
)

from place_api import (
    search_places
)

import streamlit as st

# =========================
# 이동시간 cache
# =========================

travel_time_cache = {}

# =========================
# grid 생성
# =========================

def generate_grid_points(users,grid_size=10):

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

    # =========================
    # padding
    # =========================

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

        cache_key = (
            round(user["lat"], 5),
            round(user["lng"], 5),

            round(lat, 5),
            round(lng, 5),

            user["transport"]
            )

        if cache_key in travel_time_cache:

            result = travel_time_cache[
                cache_key
                ]

        else:

            result = get_travel_time(
                user["lat"],
                user["lng"],
                lat,
                lng,
                user["transport"]
                )

            travel_time_cache[cache_key] = result

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
    # 점수 계산
    # 낮을수록 좋음
    # =========================

    score = (
        balance * 1
        + avg_time * 5
        + max_time * 1
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
        avg_time,

        "balance":
        balance,

        "max_time":
        max_time
    }


# =========================
# 시간 최적 지점 탐색
# =========================

def find_best_meeting_points(

    users
):

    grid_points = generate_grid_points(
        users
    )

    best_points = []

    total = len(grid_points)

    progress_bar = st.progress(0)

    status_text = st.empty()


    for idx, (lat, lng) in enumerate(grid_points):
        progress = (
            idx + 1
        ) / total

        progress_bar.progress(
            progress
        )

        status_text.text(

            f"추천 지점 분석 중... "
            f"{idx + 1}/{total}"
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

    progress_bar.empty()
    status_text.empty()


    # =========================
    # 점수순 정렬
    # =========================

    best_points.sort(

        key=lambda x:
        x["score"]
    )

    return best_points[:5]


# =========================
# 후보 장소 수집
# =========================

def collect_candidate_places(
    users,
    category="카페"
):

    best_points = (

        find_best_meeting_points(
            users
        )
    )

    candidate_places = []

    # =========================
    # 좋은 grid 근처 장소 검색
    # =========================

    for point in best_points:

        if category == "상관없음":

            all_categories = [
                "카페",
                "음식점",
                "영화관",
                "공원"
            ]

            places = []

            for c in all_categories:

                places.extend(
                    search_places(
                        point["lat"],
                        point["lng"],
                        c
                    )
                )

        else:

            places = search_places(
                point["lat"],
                point["lng"],
                category
            )

    candidate_places.extend(places)

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
    return unique_places[:15]

# =========================
# 최종 추천 (구조 불일치 방지를 위해 기본값 처리 추가)
# =========================

def recommend_places(
    users,
    category="카페",
    middle_lat=None,
    middle_lng=None
):

    places = collect_candidate_places(
    users,
    category
)

    recommendations = []

    # =========================
    # 진행률 UI
    # =========================

    place_progress = st.progress(0)

    place_status = st.empty()

    total_places = len(places)

    # =========================
    # 장소 평가 loop
    # =========================

    for idx, place in enumerate(places):

        # =========================
        # 진행률 업데이트
        # =========================

        progress = (
            idx + 1
        ) / total_places

        place_progress.progress(
            progress
        )

        place_status.text(

            f"추천 장소 평가 중... "
            f"{idx + 1}/{total_places}"
        )

        times = []

        user_times = []

        failed = False

        # =========================
        # 사용자별 이동시간 계산
        # =========================

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
                minutes,

                "steps":
                result.get(
                    "steps",
                    []
                )
            })

        if failed:

            continue

        # =========================
        # 점수 계산
        # =========================

        balance = (

            max(times)
            - min(times)
        )

        avg_time = (

            sum(times)
            / len(times)
        )

        max_time = max(times)

        score = (

            balance * 1

            + avg_time * 5

            + max_time * 1
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

    # =========================
    # 진행률 제거
    # =========================

    place_progress.empty()

    place_status.empty()

    # =========================
    # 점수순 정렬
    # =========================

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    return recommendations[:5]