import requests
import streamlit as st
import json

from datetime import datetime


# =========================
# API KEY
# =========================

GOOGLE_API_KEY = (
    st.secrets["GOOGLE_API_KEY"]
    .strip()
)


# =========================
# Google Place ID 검색
# =========================

def get_google_place_id(query):

    url = (
        "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
    )

    params = {

        "input":
        query,

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

        data = response.json()

        st.subheader(
            "PLACE SEARCH RESPONSE"
        )

        st.code(
            json.dumps(
                data,
                indent=2,
                ensure_ascii=False
            )
        )

        candidates = data.get(
            "candidates",
            []
        )

        # 장소 없음
        if not candidates:

            st.error(
                f"PLACE NOT FOUND: {query}"
            )

            return None

        place_id = candidates[0].get(
            "place_id"
        )

        st.success(
            f"{query} → {place_id}"
        )

        return place_id

    except Exception as e:

        st.error(
            f"PLACE SEARCH ERROR: {str(e)}"
        )

        return None


# =========================
# Routes API 이동시간 계산
# =========================

def compute_route_duration(

    origin_place_id,

    destination_place_id,

    travel_mode
):

    # =========================
    # place_id 검증
    # =========================

    if not origin_place_id:

        st.error(
            "origin_place_id 없음"
        )

        return None

    if not destination_place_id:

        st.error(
            "destination_place_id 없음"
        )

        return None

    url = (
        "https://routes.googleapis.com/directions/v2:computeRoutes"
    )

    # =========================
    # 헤더
    # =========================

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_API_KEY,

        # 매우 중요
        "X-Goog-FieldMask":
        (
            "routes.duration,"
            "routes.legs.duration"
        )
    }

    # =========================
    # 요청 body
    # =========================

    body = {

        "origin": {

            "location": {

                "placeId":
                origin_place_id
            }
        },

        "destination": {

            "location": {

                "placeId":
                destination_place_id
            }
        },

        "travelMode":
        travel_mode,

        "computeAlternativeRoutes":
        False
    }

    # =========================
    # 대중교통은 출발시간 필요
    # =========================

    if travel_mode == "TRANSIT":

        body["departureTime"] = (

            datetime.utcnow()

            .replace(microsecond=0)

            .isoformat()

            + "Z"
        )

    try:

        # =========================
        # DEBUG
        # =========================

        st.subheader(
            f"ROUTE REQUEST ({travel_mode})"
        )

        st.code(
            json.dumps(
                body,
                indent=2,
                ensure_ascii=False
            )
        )

        # =========================
        # API 요청
        # =========================

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=20
        )

        # =========================
        # DEBUG
        # =========================

        st.subheader(
            f"ROUTE STATUS ({travel_mode})"
        )

        st.code(
            response.status_code
        )

        st.subheader(
            f"ROUTE RESPONSE ({travel_mode})"
        )

        st.code(
            response.text
        )

        # =========================
        # 실패
        # =========================

        if response.status_code != 200:

            st.error(
                f"{travel_mode} API FAILED"
            )

            return None

        data = response.json()

        routes = data.get(
            "routes",
            []
        )

        # 경로 없음
        if not routes:

            st.error(
                f"{travel_mode} NO ROUTES"
            )

            return None

        route = routes[0]

        # =========================
        # duration 추출
        # =========================

        duration = route.get(
            "duration"
        )

        # fallback
        if not duration:

            legs = route.get(
                "legs",
                []
            )

            if legs:

                duration = legs[0].get(
                    "duration"
                )

        # duration 없음
        if not duration:

            st.error(
                f"{travel_mode} NO DURATION"
            )

            st.code(route)

            return None

        # =========================
        # "1234s" -> 초
        # =========================

        if isinstance(duration, str):

            seconds = int(

                duration.replace(
                    "s",
                    ""
                )
            )

        else:

            seconds = int(duration)

        # 분 변환
        minutes = max(
            1,
            seconds // 60
        )

        st.success(
            f"{travel_mode}: {minutes}분"
        )

        return minutes

    except Exception as e:

        st.error(
            f"ROUTE ERROR: {str(e)}"
        )

        return None


# =========================
# 자동차
# =========================

def get_car_travel_time(

    origin_query,

    destination_query
):

    origin_place_id = (
        get_google_place_id(
            origin_query
        )
    )

    destination_place_id = (
        get_google_place_id(
            destination_query
        )
    )

    if not origin_place_id:
        return None

    if not destination_place_id:
        return None

    return compute_route_duration(

        origin_place_id,

        destination_place_id,

        "DRIVE"
    )


# =========================
# 도보
# =========================

def get_walk_travel_time(

    origin_query,

    destination_query
):

    origin_place_id = (
        get_google_place_id(
            origin_query
        )
    )

    destination_place_id = (
        get_google_place_id(
            destination_query
        )
    )

    if not origin_place_id:
        return None

    if not destination_place_id:
        return None

    return compute_route_duration(

        origin_place_id,

        destination_place_id,

        "WALK"
    )


# =========================
# 대중교통
# =========================

def get_transit_travel_time(

    origin_query,

    destination_query
):

    origin_place_id = (
        get_google_place_id(
            origin_query
        )
    )

    destination_place_id = (
        get_google_place_id(
            destination_query
        )
    )

    if not origin_place_id:
        return None

    if not destination_place_id:
        return None

    return compute_route_duration(

        origin_place_id,

        destination_place_id,

        "TRANSIT"
    )