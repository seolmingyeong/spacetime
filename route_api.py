import requests
import streamlit as st


# =========================
# Kakao API Key
# =========================

KAKAO_REST_API_KEY = st.secrets.get(
    "KAKAO_REST_API_KEY"
)


# =========================
# Google API Key
# =========================

GOOGLE_MAPS_API_KEY = st.secrets.get(
    "GOOGLE_MAPS_API_KEY"
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

        minutes = int(
            duration / 60
        )

        if minutes <= 0:

            minutes = 1

        return minutes

    except Exception as e:

        st.error(e)

        return None


# =========================
# Google 이동시간 계산
# =========================

def get_google_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng,

    mode="walking"
):

    if not GOOGLE_MAPS_API_KEY:

        st.error(
            "GOOGLE_MAPS_API_KEY 없음"
        )

        return None

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

        if element.get("status") != "OK":

            st.error(
                f"ELEMENT STATUS = {element.get('status')}"
            )

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

        minutes = int(
            seconds / 60
        )

        if minutes <= 0:

            minutes = 1

        return minutes

    except Exception as e:

        st.error(e)

        return None


# =========================
# 도보 이동시간
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

        mode="walking"
    )


# =========================
# 대중교통 이동시간
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

        mode="transit"
    )