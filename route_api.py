import requests
import streamlit as st


# =========================
# API KEY
# =========================

KAKAO_REST_API_KEY = st.secrets.get(
    "KAKAO_REST_API_KEY"
)

GOOGLE_MAPS_API_KEY = st.secrets.get(
    "GOOGLE_MAPS_API_KEY"
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

        return max(
            1,
            int(duration / 60)
        )

    except Exception as e:

        st.error(e)

        return None


# =========================
# Google 이동시간
# =========================

def get_google_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng,

    mode
):

    url = (
        "https://maps.googleapis.com/maps/api/distancematrix/json"
    )

    params = {

        "origins":
        f"{start_lat},{start_lng}",

        "destinations":
        f"{end_lat},{end_lng}",

        "mode":
        mode,

        "language":
        "ko",

        "region":
        "kr",

        "key":
        GOOGLE_MAPS_API_KEY
    }

    try:

        response = requests.get(

            url,

            params=params,

            timeout=5
        )

        data = response.json()

        # =========================
        # DEBUG
        # =========================

        st.error(data)

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

        element = elements[0]

        st.error(element)

        if element.get("status") != "OK":

            return None

        duration = element.get(
            "duration"
        )

        if not duration:

            return None

        seconds = duration.get(
            "value"
        )

        if seconds is None:

            return None

        return max(
            1,
            int(seconds / 60)
        )

    except Exception as e:

        st.error(e)

        return None


# =========================
# 도보
# =========================

def get_walk_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    return get_google_travel_time(

        start_lat,
        start_lng,

        end_lat,
        end_lng,

        "walking"
    )


# =========================
# 대중교통
# =========================

def get_transit_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    return get_google_travel_time(

        start_lat,
        start_lng,

        end_lat,
        end_lng,

        "transit"
    )