import requests
import streamlit as st


# =========================
# Kakao API Key
# =========================

KAKAO_REST_API_KEY = st.secrets.get(
    "KAKAO_REST_API_KEY"
)


# =========================
# 자동차 이동시간 계산
# =========================

def get_car_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    if not KAKAO_REST_API_KEY:

        st.error(
            "KAKAO_REST_API_KEY 없음"
        )

        return None

    url = (
        "https://apis-navi.kakaomobility.com/v1/directions"
    )

    headers = {

        "Authorization":
        f"KakaoAK {KAKAO_REST_API_KEY}"
    }

    params = {

        # 출발지
        "origin":
        f"{start_lng},{start_lat}",

        # 도착지
        "destination":
        f"{end_lng},{end_lat}"
    }

    try:

        response = requests.get(

            url,

            headers=headers,

            params=params
        )

        data = response.json()

        routes = data.get(
            "routes"
        )

        if not routes:

            st.error(
                "routes 없음"
            )

            return None

        summary = routes[0].get(
            "summary"
        )

        if not summary:

            st.error(
                "summary 없음"
            )

            return None

        duration = summary.get(
            "duration"
        )

        if duration is None:

            st.error(
                "duration 없음"
            )

            return None

        # ms -> 분
        minutes = int(
            duration / 1000 / 60
        )

        return minutes

    except Exception as e:

        st.error(
            f"Kakao API 오류: {e}"
        )

        return None