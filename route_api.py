import requests
import streamlit as st

from datetime import datetime
import json


# =========================
# API KEY
# =========================

GOOGLE_API_KEY = st.secrets.get(
    "GOOGLE_MAP_API_KEY"
)

st.code(
    f"API KEY: {GOOGLE_API_KEY}"
)


# =========================
# Google Place ID 검색
# =========================

def get_google_place_id(query):

    query = query + " 서울"

    url = (
        "https://places.googleapis.com/v1/places:searchText"
        f"?key={GOOGLE_API_KEY}"
    )

    headers = {

    "Content-Type":
    "application/json",

    "X-Goog-FieldMask":
    "places.id,places.displayName"
    }



    body = {

        "textQuery":
        query,

        "languageCode":
        "ko"
    }

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=10
        )

        st.error("PLACE SEARCH RESPONSE")

        st.code(
            response.text
        )
        
        data = response.json()

        places = data.get(
            "places",
            []
        )

        if not places:

            st.error(
                "NO PLACES FOUND"
            )

            return None

        # =========================
        # Places API New
        # =========================

        place_id = places[0].get(
            "id"
        )

        st.success(
            f"PLACE_ID: {place_id}"
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
        GOOGLE_API_KEY,

        "X-Goog-FieldMask":
        "routes.duration"
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

        body["routingPreference"] = (
            "LESS_WALKING"
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
            f"ROUTE RESPONSE ({travel_mode})"
        )

        st.code(
            response.text
        )

        data = response.json()

        routes = data.get(
            "routes",
            []
        )

        if not routes:

            st.error(
                "NO ROUTES FOUND"
            )

            return None

        duration_str = routes[0].get(
            "duration"
        )

        if not duration_str:

            st.error(
                "NO DURATION"
            )

            return None

        seconds = int(

            duration_str.replace(
                "s",
                ""
            )
        )

        minutes = int(
            seconds / 60
        )

        if minutes <= 0:

            minutes = 1

        st.success(
            f"{travel_mode} TIME: {minutes}분"
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

    st.code(
        f"CAR PLACE IDS:\n{origin_place_id}\n{destination_place_id}"
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

    st.code(
        f"WALK PLACE IDS:\n{origin_place_id}\n{destination_place_id}"
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

    st.code(
        f"TRANSIT PLACE IDS:\n{origin_place_id}\n{destination_place_id}"
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