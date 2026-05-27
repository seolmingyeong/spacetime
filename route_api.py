import requests
import streamlit as st


# =========================
# API Keys
# =========================

KAKAO_REST_API_KEY = st.secrets.get(
    "KAKAO_REST_API_KEY"
)

GOOGLE_API_KEY = st.secrets.get(
    "GOOGLE_API_KEY"
)


# =========================
# 자동차 이동시간
# =========================

def get_car_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    url = (
        "https://apis-navi.kakaomobility.com/v1/directions"
    )

    headers = {

        "Authorization":
        f"KakaoAK {KAKAO_REST_API_KEY}"
    }

    params = {

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

            timeout=3
        )

        data = response.json()

        routes = data.get(
            "routes"
        )

        if not routes:

            return None

        duration = routes[0][
            "summary"
        ][
            "duration"
        ]

        return int(
            duration / 60
        )

    except Exception:

        return None


# =========================
# Google 도보 이동시간
# =========================

def get_walk_travel_time(

    origin_address,

    destination_address
):

    url = (
        "https://maps.googleapis.com/maps/api/distancematrix/json"
    )

    params = {

        "origins":
        origin_address,

        "destinations":
        destination_address,

        "mode":
        "walking",

        "language":
        "ko",

        "region":
        "kr",

        "key":
        GOOGLE_API_KEY
    }

    try:

        response = requests.get(

            url,

            params=params,

            timeout=3
        )

        data = response.json()

        rows = data.get(
            "rows",
            []
        )

        if not rows:

            return None

        elements = rows[0].get(
            "elements",
            []
        )

        if not elements:

            return None

        result = elements[0]

        if result.get(
            "status"
        ) != "OK":

            return None

        duration = result[
            "duration"
        ][
            "value"
        ]

        return int(
            duration / 60
        )

    except Exception:

        return None


# =========================
# 대중교통 이동시간
# =========================

def get_transit_travel_time(

    origin_address,

    destination_address
):

    # =========================
    # 임시 fallback
    # =========================

    return get_walk_travel_time(

        origin_address,

        destination_address
    )