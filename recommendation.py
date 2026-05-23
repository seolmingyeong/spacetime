from route_api import (
    get_car_travel_time
)

import streamlit as st


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
# 후보 위치 생성
# =========================

def generate_candidates(

    middle_lat,
    middle_lng
):

    offset = 0.005

    return [

        (
            middle_lat,
            middle_lng
        ),

        (
            middle_lat + offset,
            middle_lng
        ),

        (
            middle_lat - offset,
            middle_lng
        ),

        (
            middle_lat,
            middle_lng + offset
        ),

        (
            middle_lat,
            middle_lng - offset
        )
    ]


# =========================
# 추천 장소 생성
# =========================

def recommend_places(

    users,

    middle_lat,
    middle_lng
):

    st.write(
        "recommend_places 실행됨"
    )

    candidates = generate_candidates(

        middle_lat,
        middle_lng
    )

    best_place = None

    best_score = float("inf")

    for lat, lng in candidates:

        st.write(
            "후보 위치:",
            lat,
            lng
        )

        times = []

        user_times = []

        for user in users:

            st.write(
                "사용자:",
                user["nickname"]
            )

            travel_time = (

                get_car_travel_time(

                    user["lat"],
                    user["lng"],

                    lat,
                    lng
                )
            )

            st.write(
                "이동시간:",
                travel_time
            )

            # =========================
            # 실패
            # =========================

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

        st.write(
            "times:",
            times
        )

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

        st.write(
            "score:",
            score
        )

        if score < best_score:

            best_score = score

            best_place = {

                "name":
                "최적 약속 장소",

                "lat":
                lat,

                "lng":
                lng,

                "address":
                "이동시간 기반 추천",

                "avg_time":
                avg_time,

                "max_time":
                max_time,

                "user_times":
                user_times
            }

    st.write(
        "best_place:",
        best_place
    )

    if best_place is None:

        return []

    return [best_place]