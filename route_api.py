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

            timeout=5
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
# Google Distance Matrix
# =========================

def get_google_travel_time(

    origin,

    destination,

    mode
):

    url = (
        "https://maps.googleapis.com/maps/api/distancematrix/json"
    )

    params = {

        "origins":
        origin,

        "destinations":
        destination,

        "mode":
        mode,

        "language":
        "ko",

        "region":
        "kr",

        "key":
        GOOGLE_API_KEY
    }

    # =========================
    # transit 추가 설정
    # =========================

    if mode == "transit":

        params["transit_mode"] = (
            "bus|subway"
        )

    try:

        response = requests.get(

            url,

            params=params,

            timeout=10
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
# 도보 이동시간
# =========================

def get_walk_travel_time(

    origin_address,

    destination_address
):

    return get_google_travel_time(

        origin_address,

        destination_address,

        "walking"
    )


# =========================
# 대중교통 이동시간
# =========================

def get_transit_travel_time(

    origin_address,

    destination_address
):

    return get_google_travel_time(

        origin_address,

        destination_address,

        "transit"
    )