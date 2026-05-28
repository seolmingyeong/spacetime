import requests
import streamlit as st

from datetime import datetime


GOOGLE_API_KEY = (
    st.secrets["GOOGLE_API_KEY"]
    .strip()
)


# =========================
# 이동 시간 계산
# =========================

def get_travel_time(

    origin_lat,
    origin_lng,

    destination_lat,
    destination_lng,

    transport
):

    # =========================
    # 좌표 검증
    # =========================

    if origin_lat is None:

        print("ORIGIN LAT NONE")

        return None

    if origin_lng is None:

        print("ORIGIN LNG NONE")

        return None

    if destination_lat is None:

        print("DESTINATION LAT NONE")

        return None

    if destination_lng is None:

        print("DESTINATION LNG NONE")

        return None

    # =========================
    # 이동수단 변환
    # =========================

    TRANSPORT_MAP = {

        "도보": "WALKING",

        "자동차": "DRIVE",

        "대중교통": "TRANSIT"
    }

    transport = str(
        transport
    ).strip()

    travel_mode = TRANSPORT_MAP.get(
        transport
    )

    # =========================
    # 이동수단 오류
    # =========================

    if not travel_mode:

        print()
        print("INVALID TRANSPORT")

        print(repr(transport))

        return None

    # =========================
    # Routes API
    # =========================

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

    # =========================
    # 요청 body
    # =========================

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
    # 자동차 옵션
    # =========================

    if travel_mode == "DRIVE":

        body["routingPreference"] = (
            "TRAFFIC_AWARE"
        )

    # =========================
    # 대중교통 옵션
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

    # =========================
    # DEBUG
    # =========================

    print()
    print("===== ROUTE DEBUG =====")

    print()

    print("ORIGIN")

    print(origin_lat, origin_lng)

    print()

    print("DESTINATION")

    print(destination_lat, destination_lng)

    print()

    print("TRANSPORT")

    print(transport)

    print()

    print("TRAVEL MODE")

    print(travel_mode)

    print()

    print("REQUEST BODY")

    print(body)

    # =========================
    # 요청
    # =========================

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=15
        )

    except Exception as e:

        print()
        print("REQUEST ERROR")

        print(str(e))

        return None

    # =========================
    # RESPONSE DEBUG
    # =========================

    print()
    print("RESPONSE STATUS")

    print(response.status_code)

    print()
    print("RESPONSE TEXT")

    print(response.text)

    # =========================
    # 실패 처리
    # =========================

    if response.status_code != 200:

        print()
        print("ROUTES API FAILED")

        return None

    # =========================
    # 응답 파싱
    # =========================

    try:

        data = response.json()

    except Exception as e:

        print()
        print("JSON PARSE ERROR")

        print(str(e))

        return None

    routes = data.get(
        "routes",
        []
    )

    if not routes:

        print()
        print("ROUTES EMPTY")

        return None

    duration = routes[0].get(
        "duration"
    )

    if not duration:

        print()
        print("DURATION EMPTY")

        return None

    # =========================
    # duration -> minutes
    # =========================

    try:

        seconds = float(

            duration.replace(
                "s",
                ""
            )
        )

    except Exception as e:

        print()
        print("DURATION PARSE ERROR")

        print(duration)

        print(str(e))

        return None

    minutes = round(
        seconds / 60
    )

    print()
    print("FINAL TIME")

    print(minutes)

    return minutes