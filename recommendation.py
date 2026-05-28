from route_api import (
    get_travel_time
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

    ).strip()

    # =========================
    # 사용자 좌표
    # =========================

    origin_lat = user.get(
        "lat"
    )

    origin_lng = user.get(
        "lng"
    )

    # =========================
    # 목적지 좌표
    # =========================

    destination_lat = place.get(
        "lat"
    )

    destination_lng = place.get(
        "lng"
    )

    # =========================
    # 좌표 검증
    # =========================

    if origin_lat is None:

        st.error(
            f"{user['nickname']} origin_lat 없음"
        )

        return None

    if origin_lng is None:

        st.error(
            f"{user['nickname']} origin_lng 없음"
        )

        return None

    if destination_lat is None:

        st.error(
            f"{place['name']} destination_lat 없음"
        )

        return None

    if destination_lng is None:

        st.error(
            f"{place['name']} destination_lng 없음"
        )

        return None

    # =========================
    # DEBUG
    # =========================

    st.write(
        "출발지 좌표:",
        origin_lat,
        origin_lng
    )

    st.write(
        "목적지 좌표:",
        destination_lat,
        destination_lng
    )

    st.write(
        "이동수단:",
        transport
    )

    # =========================
    # 이동시간 계산
    # =========================

    return get_travel_time(

        origin_lat,
        origin_lng,

        destination_lat,
        destination_lng,

        transport
    )


# =========================
# 후보 장소 수집
# =========================

def collect_candidate_places(users):

    candidate_places = []

    search_points = []

    # =========================
    # 사용자 위치 확인
    # =========================

    for user in users:

        lat = user.get("lat")
        lng = user.get("lng")

        if lat is None or lng is None:

            st.error(
                f"{user['nickname']} 좌표 없음"
            )

            continue

        search_points.append(
            (lat, lng)
        )

    # =========================
    # 사용자 사이 중간지점
    # =========================

    for i in range(len(users)):

        for j in range(i + 1, len(users)):

            lat1 = users[i]["lat"]
            lng1 = users[i]["lng"]

            lat2 = users[j]["lat"]
            lng2 = users[j]["lng"]

            if (
                lat1 is None
                or lng1 is None
                or lat2 is None
                or lng2 is None
            ):

                continue

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

    st.subheader(
        "SEARCH POINTS"
    )

    st.code(search_points)

    # =========================
    # 장소 검색
    # =========================

    for lat, lng in search_points:

        try:

            places = search_places(

                lat,
                lng,

                "카페"
            )

            st.write(
                f"{lat}, {lng} → {len(places)}개"
            )

            candidate_places.extend(
                places
            )

        except Exception as e:

            st.error(
                f"장소 검색 실패: {str(e)}"
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

    st.subheader(
        "UNIQUE PLACES"
    )

    st.code(unique_places)

    return unique_places[:10]

# =========================
# 추천 장소 생성
# =========================

def recommend_places(users):

    st.subheader(
        "USERS"
    )

    st.code(users)

    places = collect_candidate_places(
        users
    )

    st.subheader(
        "CANDIDATE PLACES"
    )

    st.code(places)

    recommendations = []

    for place in places:

        st.markdown(
            f"## 평가 중: {place['name']}"
        )

        times = []

        user_times = []

        failed = False

        for user in users:

            travel_info = (

                get_real_travel_time(

                    user,

                    place
                )
            )

            if travel_info is None:

                failed = True

                break

            travel_time = (
                travel_info["minutes"]
            )

            route_polyline = (
                travel_info["polyline"]
            )


            st.write(

                user["nickname"],

                user["transport"],

                travel_time
            )

            if travel_time is None:

                failed = True

                st.error(
                    f"{place['name']} 계산 실패"
                )

                break

            # =========================
            # 너무 긴 이동시간 제거
            # =========================

            if travel_time > 90:

                failed = True

                st.warning(
                    f"{place['name']} 이동시간 너무 김"
                )

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

        # =========================
        # 점수 계산
        # =========================

        balance_score = (

            max(times)
            - min(times)
        )

        avg_score = (

            sum(times)
            / len(times)
        )

        max_time = max(times)

        # =========================
        # 최종 점수
        # 낮을수록 좋음
        # =========================

        score = (

            balance_score * 1.5

            + avg_score * 0.5

            + max_time * 0.3
        )

        recommendations.append({

            "name":
            place["name"],

            "place_id":
            place.get("place_id"),

            "lat":
            place["lat"],

            "lng":
            place["lng"],

            "address":
            place["address"],

            "avg_time":
            int(avg_score),

            "max_time":
            max_time,

            "balance":
            balance_score,

            "score":
            round(score, 2),

            "user_times":
            user_times
        })

        st.success(
            f"{place['name']} 추가 완료"
        )

    # =========================
    # 점수순 정렬
    # =========================

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    st.subheader(
        "FINAL RECOMMENDATIONS"
    )

    st.code(recommendations)

    return recommendations[:5]