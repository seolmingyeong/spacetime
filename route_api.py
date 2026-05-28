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
            ""
        )

    ).strip()

    st.warning(
        f"TRANSPORT = [{transport}]"
    )

    origin_query = (
        user.get(
            "location_name"
        )
    )

    destination_query = (
        place.get(
            "name"
        )
    )

    st.code(
        f"{origin_query} → {destination_query}"
    )

    if not origin_query:

        st.error(
            "NO ORIGIN"
        )

        return None

    if not destination_query:

        st.error(
            "NO DESTINATION"
        )

        return None

    # =========================
    # 자동차
    # =========================

    if "자동차" in transport:

        st.success(
            "CAR MODE"
        )

        return get_car_travel_time(

            origin_query,

            destination_query
        )

    # =========================
    # 도보
    # =========================

    elif "도보" in transport:

        st.success(
            "WALK MODE"
        )

        return get_walk_travel_time(

            origin_query,

            destination_query
        )

    # =========================
    # 대중교통
    # =========================

    elif "대중교통" in transport:

        st.success(
            "TRANSIT MODE"
        )

        return get_transit_travel_time(

            origin_query,

            destination_query
        )

    # =========================
    # 알 수 없는 이동수단
    # =========================

    st.error(
        f"UNKNOWN TRANSPORT: [{transport}]"
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

    # =========================
    # 중간 지점 생성
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

        st.write(
            f"PLACE SEARCH: {lat}, {lng}"
        )

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

    st.success(
        f"PLACE COUNT: {len(unique_places)}"
    )

    # =========================
    # API 폭발 방지
    # =========================

    return unique_places[:5]


# =========================
# 추천 장소 생성
# =========================

def recommend_places(users):

    st.header(
        "recommend 시작"
    )

    places = collect_candidate_places(
        users
    )

    recommendations = []

    for place in places:

        st.subheader(
            f"평가 중: {place['name']}"
        )

        times = []

        user_times = []

        failed = False

        for user in users:

            st.write(
                f"{user['nickname']} 계산 시작"
            )

            travel_time = get_real_travel_time(

                user,

                place
            )

            st.write(

                "RESULT:",

                user["nickname"],

                travel_time
            )

            if travel_time is None:

                st.error(
                    "ROUTE FAILED"
                )

                failed = True

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

        if failed:

            continue

        if not times:

            continue

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

    st.header(
        "recommend 끝"
    )

    return recommendations[:3]