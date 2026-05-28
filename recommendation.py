from route_api import (
    compute_route_duration
)

from place_api import (
    search_places,
    search_place_id
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
    # 사용자 출발지 place_id
    # =========================

    origin_place_id = user.get(
        "place_id"
    )

    # =========================
    # 목적지 place_id
    # =========================

    destination_place_id = place.get(
        "place_id"
    )

    # =========================
    # 사용자 place_id 없으면 검색
    # =========================

    if not origin_place_id:

        location_name = user.get(
            "location_name"
        )

        if not location_name:

            st.error(
                f"{user['nickname']} location_name 없음"
            )

            return None

        origin_place_id = (
            search_place_id(
                location_name
            )
        )

    # =========================
    # 장소 place_id 없으면 검색
    # =========================

    if not destination_place_id:

        destination_name = place.get(
            "name"
        )

        if not destination_name:

            st.error(
                "destination_name 없음"
            )

            return None

        destination_place_id = (
            search_place_id(
                destination_name
            )
        )

    # =========================
    # place_id 실패
    # =========================

    if not origin_place_id:

        st.error(
            f"{user['nickname']} 출발지 place_id 실패"
        )

        return None

    if not destination_place_id:

        st.error(
            f"{place['name']} 목적지 place_id 실패"
        )

        return None

    # =========================
    # DEBUG
    # =========================

    st.write(
        "출발지:",
        origin_place_id
    )

    st.write(
        "목적지:",
        destination_place_id
    )

    st.write(
        "이동수단:",
        transport
    )

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

    st.error(
        f"알 수 없는 이동수단: {transport}"
    )

    return None


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

            # 좌표 없으면 스킵
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

    # =========================
    # DEBUG
    # =========================

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

    # =========================
    # 후보 장소
    # =========================

    places = collect_candidate_places(
        users
    )

    st.subheader(
        "CANDIDATE PLACES"
    )

    st.code(places)

    recommendations = []

    # =========================
    # 장소 평가
    # =========================

    for place in places:

        st.markdown(
            f"## 평가 중: {place['name']}"
        )

        times = []

        user_times = []

        failed = False

        for user in users:

            travel_time = (

                get_real_travel_time(

                    user,

                    place
                )
            )

            st.write(

                user["nickname"],

                user["transport"],

                travel_time
            )

            # 실패
            if travel_time is None:

                failed = True

                st.error(
                    f"{place['name']} 계산 실패"
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

        # 실패 장소 제외
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

        score = (

            balance_score
            + avg_score * 0.3
        )

        recommendations.append({

            "name":
            place["name"],

            "place_id":
            place["place_id"],

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

        st.success(
            f"{place['name']} 추가 완료"
        )

    # =========================
    # 점수 정렬
    # =========================

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    st.subheader(
        "FINAL RECOMMENDATIONS"
    )

    st.code(recommendations)

    return recommendations[:3]