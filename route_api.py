import requests
import streamlit as st

from datetime import datetime
import json


# =========================
# API KEY
# =========================

GOOGLE_API_KEY = (
    st.secrets["GOOGLE_API_KEY"]
    .strip()
)


# =========================
# 장소 검색
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

        if not candidates:

            st.error(
                f"NO PLACE: {query}"
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
            f"PLACE ERROR: {str(e)}"
        )

        return None


# =========================
# Routes API
# =========================

def compute_route_duration(

    origin_place_id,

    destination_place_id,

    travel_mode
):

    url = (
        "https://routes.googleapis.com/directions/v2:computeRoutes"
    )

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_API_KEY
    }

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
    # TRANSIT
    # =========================

    if travel_mode == "TRANSIT":

        body["departureTime"] = (

            datetime.utcnow()

            .replace(microsecond=0)

            .isoformat()

            + "Z"
        )

    try:

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

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=20
        )

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

        # =========================
        # WALK fallback
        # =========================

        if not duration:

            legs = route.get(
                "legs",
                []
            )

            if legs:

                duration = legs[0].get(
                    "duration"
                )

        # =========================
        # duration 실패
        # =========================

        if not duration:

            st.error(
                f"{travel_mode} NO DURATION"
            )

            st.code(route)

            return None

        # =========================
        # "1234s"
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