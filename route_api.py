import requests
import streamlit as st

from datetime import datetime


GOOGLE_API_KEY = (
    st.secrets["GOOGLE_API_KEY"]
    .strip()
)


# =========================
# 장소명 -> Place ID
# =========================

def get_google_place_id(
    place_name
):

    url = (
        "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
    )

    params = {

        "input":
        place_name,

        "inputtype":
        "textquery",

        "fields":
        "place_id,name",

        "language":
        "ko",

        "key":
        GOOGLE_API_KEY
    }

    try:

        response = requests.get(

            url,

            params=params,

            timeout=10
        )

        print()
        print("PLACE SEARCH STATUS")

        print(response.status_code)

        data = response.json()

        print()
        print("PLACE SEARCH RESPONSE")

        print(data)

        candidates = data.get(
            "candidates",
            []
        )

        if not candidates:

            print("PLACE SEARCH EMPTY")

            return None

        place_id = candidates[0].get(
            "place_id"
        )

        # =========================
        # place_id 검증
        # =========================

        if not place_id:

            print("PLACE_ID NONE")

            return None

        if not str(place_id).startswith(
            "ChIJ"
        ):

            print("INVALID PLACE_ID")

            print(place_id)

            return None

        return place_id

    except Exception as e:

        print("PLACE SEARCH ERROR")

        print(str(e))

        return None


# =========================
# 이동 시간 계산
# =========================

def get_travel_time(

    origin_place_id,

    destination_place_id,

    transport
):

    # =========================
    # place_id 검증
    # =========================

    if not origin_place_id:

        print("ORIGIN PLACE_ID NONE")

        return None

    if not destination_place_id:

        print("DESTINATION PLACE_ID NONE")

        return None

    if not str(origin_place_id).startswith(
        "ChIJ"
    ):

        print("INVALID ORIGIN PLACE_ID")

        print(origin_place_id)

        return None

    if not str(destination_place_id).startswith(
        "ChIJ"
    ):

        print("INVALID DESTINATION PLACE_ID")

        print(destination_place_id)

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

            "placeId":
            origin_place_id
        },

        "destination": {

            "placeId":
            destination_place_id
        },

        "travelMode":
        travel_mode,

        "computeAlternativeRoutes":
        False
    }

    # =========================
    # DRIVE 옵션
    # =========================

    if travel_mode == "DRIVE":

        body["routingPreference"] = (
            "TRAFFIC_AWARE"
        )

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

    # =========================
    # DEBUG
    # =========================

    print()
    print("===== ROUTE DEBUG =====")

    print()

    print("ORIGIN PLACE_ID")

    print(origin_place_id)

    print()

    print("DESTINATION PLACE_ID")

    print(destination_place_id)

    print()

    print("TRANSPORT")

    print(repr(transport))

    print()

    print("TRAVEL MODE")

    print(travel_mode)

    print()

    print("REQUEST BODY")

    print(body)

    # =========================
    # API 요청
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
    print("FINAL TRAVEL TIME")

    print(f"{minutes}분")

    return minutes