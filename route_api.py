import requests
import streamlit as st

from datetime import datetime


GOOGLE_API_KEY = (
    st.secrets["GOOGLE_API_KEY"]
    .strip()
)

KAKAO_REST_API_KEY = (
    st.secrets["KAKAO_REST_API_KEY"]
    .strip()
)


# =========================
# 카카오 자동차 이동시간
# =========================

def get_kakao_drive_time(

    origin_lat,
    origin_lng,

    destination_lat,
    destination_lng
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
        f"{origin_lng},{origin_lat}",

        "destination":
        f"{destination_lng},{destination_lat}"
    }

    try:

        response = requests.get(

            url,

            headers=headers,

            params=params,

            timeout=15
        )

    except:

        return None

    if response.status_code != 200:

        return None

    try:

        data = response.json()

    except:

        return None

    routes = data.get(
        "routes",
        []
    )

    if not routes:

        return None

    summary = routes[0].get(
        "summary",
        {}
    )

    duration = summary.get(
        "duration"
    )

    if duration is None:

        return None

    minutes = round(
        duration / 60
    )

    return {

        "minutes":
        minutes,

        "steps": [

            {

                "mode":
                "DRIVE",

                "minutes":
                minutes
            }
        ]
    }


# =========================
# 구글 대중교통 이동시간
# =========================

def get_google_transit_time(

    origin_lat,
    origin_lng,

    destination_lat,
    destination_lng
):

    url = (
        "https://routes.googleapis.com/directions/v2:computeRoutes"
    )

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_API_KEY,

        "X-Goog-FieldMask":
        (
            "routes.duration,"
            "routes.legs.steps.travelMode,"
            "routes.legs.steps.staticDuration"
        )
    }

    body = {

        "origin": {

            "location": {

                "latLng": {

                    "latitude":
                    origin_lat,

                    "longitude":
                    origin_lng
                }
            }
        },

        "destination": {

            "location": {

                "latLng": {

                    "latitude":
                    destination_lat,

                    "longitude":
                    destination_lng
                }
            }
        },

        "travelMode":
        "TRANSIT",

        "departureTime": (

            datetime.utcnow()

            .replace(
                microsecond=0
            )

            .isoformat()

            + "Z"
        )
    }

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=15
        )

    except:

        return None

    if response.status_code != 200:

        return None

    try:

        data = response.json()

    except:

        return None

    routes = data.get(
        "routes",
        []
    )

    if not routes:

        return None

    route = routes[0]

    duration = route.get(
        "duration"
    )

    if not duration:

        return None

    try:

        seconds = float(

            duration.replace(
                "s",
                ""
            )
        )

    except:

        return None

    minutes = round(
        seconds / 60
    )

    # =========================
    # step 정보 추출
    # =========================

    step_infos = []

    try:

        legs = route.get(
            "legs",
            []
        )

        if legs:

            steps = legs[0].get(
                "steps",
                []
            )

            for step in steps:

                mode = step.get(
                    "travelMode",
                    "UNKNOWN"
                )

                duration = step.get(
                    "staticDuration",
                    "0s"
                )

                try:

                    step_seconds = int(

                        duration.replace(
                            "s",
                            ""
                        )
                    )

                except:

                    step_seconds = 0

                step_minutes = round(
                    step_seconds / 60
                )

                step_infos.append({

                    "mode":
                    mode,

                    "minutes":
                    step_minutes
                })

    except:

        step_infos = []

    return {

        "minutes":
        minutes,

        "steps":
        step_infos
    }


# =========================
# 통합 이동시간 함수
# =========================

def get_travel_time(

    origin_lat,
    origin_lng,

    destination_lat,
    destination_lng,

    transport
):

    # =========================
    # 자동차
    # =========================

    if transport == "자동차":

        return get_kakao_drive_time(

            origin_lat,
            origin_lng,

            destination_lat,
            destination_lng
        )

    # =========================
    # 대중교통
    # =========================

    return get_google_transit_time(

        origin_lat,
        origin_lng,

        destination_lat,
        destination_lng
    )