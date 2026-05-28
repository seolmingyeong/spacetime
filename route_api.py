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

    print()
    print("===== KAKAO DRIVE DEBUG =====")

    print(params)

    try:

        response = requests.get(

            url,

            headers=headers,

            params=params,

            timeout=15
        )

    except Exception as e:

        print("KAKAO REQUEST ERROR")

        print(str(e))

        return None

    print()
    print("KAKAO STATUS")

    print(response.status_code)

    print()
    print("KAKAO RESPONSE")

    print(response.text)

    if response.status_code != 200:

        return None

    try:

        data = response.json()

    except Exception as e:

        print("KAKAO JSON ERROR")

        print(str(e))

        return None

    routes = data.get(
        "routes",
        []
    )

    if not routes:

        print("KAKAO ROUTES EMPTY")

        return None

    summary = routes[0].get(
        "summary",
        {}
    )

    duration = summary.get(
        "duration"
    )

    if duration is None:

        print("KAKAO DURATION EMPTY")

        return None

    # milliseconds -> minutes

    minutes = round(
        duration / 1000 / 60
    )

    print()
    print("KAKAO FINAL TIME")

    print(minutes)

    return minutes


# =========================
# 구글 이동시간
# =========================

def get_google_travel_time(

    origin_lat,
    origin_lng,

    destination_lat,
    destination_lng,

    transport
):

    TRANSPORT_MAP = {

        "도보": "WALKING",

        "대중교통": "TRANSIT"
    }

    travel_mode = TRANSPORT_MAP.get(
        transport
    )

    if not travel_mode:

        print("INVALID GOOGLE MODE")

        return None

    url = (
        "https://routes.googleapis.com/directions/v2:computeRoutes"
    )

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_API_KEY,

        "X-Goog-FieldMask":
        "routes.duration"
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
        travel_mode
    }

    # =========================
    # TRANSIT 옵션
    # =========================

    if travel_mode == "TRANSIT":

        body["departureTime"] = (

            datetime.utcnow()

            .replace(
                microsecond=0
            )

            .isoformat()

            + "Z"
        )

    print()
    print("===== GOOGLE ROUTE DEBUG =====")

    print(body)

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=15
        )

    except Exception as e:

        print("GOOGLE REQUEST ERROR")

        print(str(e))

        return None

    print()
    print("GOOGLE STATUS")

    print(response.status_code)

    print()
    print("GOOGLE RESPONSE")

    print(response.text)

    if response.status_code != 200:

        return None

    try:

        data = response.json()

    except Exception as e:

        print("GOOGLE JSON ERROR")

        print(str(e))

        return None

    routes = data.get(
        "routes",
        []
    )

    if not routes:

        print("GOOGLE ROUTES EMPTY")

        return None

    duration = routes[0].get(
        "duration"
    )

    if not duration:

        print("GOOGLE DURATION EMPTY")

        return None

    try:

        seconds = float(

            duration.replace(
                "s",
                ""
            )
        )

    except Exception as e:

        print("GOOGLE DURATION PARSE ERROR")

        print(str(e))

        return None

    minutes = round(
        seconds / 60
    )

    print()
    print("GOOGLE FINAL TIME")

    print(minutes)

    return minutes


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
    # 자동차 -> 카카오
    # =========================

    if transport == "자동차":

        return get_kakao_drive_time(

            origin_lat,
            origin_lng,

            destination_lat,
            destination_lng
        )

    # =========================
    # 도보/대중교통 -> 구글
    # =========================

    return get_google_travel_time(

        origin_lat,
        origin_lng,

        destination_lat,
        destination_lng,

        transport
    )