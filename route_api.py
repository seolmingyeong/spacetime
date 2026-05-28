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

    response = requests.get(

        url,

        params=params,

        timeout=10
    )

    data = response.json()

    candidates = data.get(
        "candidates",
        []
    )

    if not candidates:

        return None

    return candidates[0].get(
        "place_id"
    )


# =========================
# 이동 시간 계산
# =========================

def get_travel_time(

    origin_place_id,

    destination_place_id,

    transport
):

    # =========================
    # place_id 없는 경우
    # =========================

    if (
        not origin_place_id
        or
        not destination_place_id
    ):

        print("PLACE_ID NONE")

        return None

    # =========================
    # 이동수단 변환
    # =========================

    TRANSPORT_MAP = {

        "도보": "WALKING",

        "자동차": "DRIVE",

        "대중교통": "TRANSIT"
    }

    travel_mode = (
        TRANSPORT_MAP.get(
            transport,
            "WALK"
        )
    )

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
    # 핵심 수정 부분
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
    # TRANSIT 추가 옵션
    # =========================

    if travel_mode == "TRANSIT":

        body["departureTime"] = (

            datetime.utcnow()
            .isoformat("T")

            + "Z"
        )

    # =========================
    # DEBUG
    # =========================

    print()
    print("출발지:", origin_place_id)
    print("목적지:", destination_place_id)
    print("이동수단:", transport)

    print()
    print(f"ROUTE REQUEST ({travel_mode})")

    print(body)

    # =========================
    # 요청
    # =========================

    response = requests.post(

        url,

        headers=headers,

        json=body,

        timeout=15
    )

    print()
    print(f"ROUTE STATUS ({travel_mode})")

    print(response.status_code)

    print()
    print(f"ROUTE RESPONSE ({travel_mode})")

    try:

        print(
            response.json()
        )

    except:

        print(
            response.text
        )

    # =========================
    # 실패
    # =========================

    if response.status_code != 200:

        print(f"{travel_mode} API FAILED")

        return None

    data = response.json()

    routes = data.get(
        "routes",
        []
    )

    if not routes:

        print("ROUTES EMPTY")

        return None

    duration = routes[0].get(
        "duration"
    )

    if not duration:

        print("DURATION EMPTY")

        return None

    # =========================
    # "1234s" -> 분 변환
    # =========================

    seconds = int(
        duration.replace(
            "s",
            ""
        )
    )

    minutes = round(
        seconds / 60
    )

    print()
    print(f"{travel_mode} 이동시간:")

    print(f"{minutes}분")

    return minutes