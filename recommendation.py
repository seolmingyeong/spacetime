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

    st.write("recommend_places 실행됨")

    # =========================
    # 중간지점 근처 장소 검색
    # =========================

    places = search_places(

        middle_lat,
        middle_lng,

        "카페"
    )

    st.write("검색된 장소 수:", len(places))

    recommendations = []

    # =========================
    # 장소별 이동시간 계산
    # =========================

    for place in places:

        lat = place["lat"]
        lng = place["lng"]

        st.write(
            "후보 장소:",
            place["name"]
        )

        times = []

        user_times = []

        # =========================
        # 사용자별 이동시간 계산
        # =========================

        for user in users:

            raw_transport = user.get(
                "transport"
            )

            transport = str(

                raw_transport

            ).strip().lower()

            st.write(
                "RAW TRANSPORT =",
                raw_transport
            )

            st.write(
                "NORMALIZED =",
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

                st.write(
                    "자동차 분기 진입"
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
                    "CAR =",
                    travel_time
                )

            # =========================
            # 도보
            # =========================

            elif transport in [

                "도보",
                "walk",
                "walking"
            ]:

                st.write(
                    "도보 분기 진입"
                )

                travel_time = (

                    get_walk_travel_time(

                        user["lat"],
                        user["lng"],

                        lat,
                        lng
                    )
                )

                st.write(
                    "WALK =",
                    travel_time
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

                st.write(
                    "대중교통 분기 진입"
                )

                travel_time = (

                    get_transit_travel_time(

                        user["lat"],
                        user["lng"],

                        lat,
                        lng
                    )
                )

                st.write(
                    "TRANSIT =",
                    travel_time
                )

            # =========================
            # 기본값
            # =========================

            else:

                st.write(
                    "기본 자동차 분기 진입"
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
                    "DEFAULT CAR =",
                    travel_time
                )

            # =========================
            # 계산 실패
            # =========================

            if travel_time is None:

                st.write(
                    "travel_time is None"
                )

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

        st.write("times =", times)

        # =========================
        # 계산 실패
        # =========================

        if len(times) == 0:

            st.write(
                "times 비어있음 → skip"
            )

            continue

        # =========================
        # 평균/최대 시간 계산
        # =========================

        avg_time = int(

            sum(times)
            / len(times)
        )

        max_time = max(times)

        st.write(
            "avg_time =",
            avg_time
        )

        st.write(
            "max_time =",
            max_time
        )

        # =========================
        # 추천 점수
        # =========================

        score = (
            avg_time
            + max_time
        )

        st.write(
            "score =",
            score
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

    st.write(
        "최종 recommendations 개수 =",
        len(recommendations)
    )

    # =========================
    # score 기준 정렬
    # =========================

    recommendations.sort(

        key=lambda x:
        x["score"]
    )

    st.write(
        "정렬 완료"
    )

    # =========================
    # 상위 3개 반환
    # =========================

    result = recommendations[:3]

    st.write(
        "최종 반환값 =",
        result
    )

    return result