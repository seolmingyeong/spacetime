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

        # 카카오는 lng,lat 순서
        "origin":
        f"{start_lng},{start_lat}",

        "destination":
        f"{end_lng},{end_lat}"
    }

    try:

        response = requests.get(

            url,

            headers=headers,

            params=params,

            timeout=5
        )

        data = response.json()

        routes = data.get(
            "routes"
        )

        if not routes:

            return None

        summary = routes[0].get(
            "summary"
        )

        if not summary:

            return None

        duration = summary.get(
            "duration"
        )

        if duration is None:

            return None

        # =========================
        # 카카오는 초(second) 단위
        # =========================

        minutes = int(
            duration / 60
        )

        # 최소 1분 처리
        if minutes <= 0:

            minutes = 1

        return minutes

    except Exception:

        return None