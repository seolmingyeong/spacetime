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

st.code(
    f"KEY LENGTH: {len(GOOGLE_API_KEY)}"
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
                "NO CANDIDATES"
            )

            return None

        place_id = candidates[0].get(
            "place_id"
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
# place_id -> lat/lng
# =========================

def get_place_location(place_id):

    url = (
        "https://maps.googleapis.com/maps/api/place/details/json"
    )

    params = {

        "place_id":
        place_id,

        "fields":
        "geometry",

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
            "PLACE DETAILS RESPONSE"
        )

        st.code(
            json.dumps(
                data,
                indent=2,
                ensure_ascii=False
            )
        )

        result = data.get(
            "result"
        )

        if not result:

            st.error(
                "NO PLACE DETAILS"
            )

            return None

        geometry = result.get(
            "geometry",
            {}
        )

        location = geometry.get(
            "location",
            {}
        )

        lat = location.get(
            "lat"
        )

        lng = location.get(
            "lng"
        )

        if lat is None or lng is None:

            st.error(
                "NO LAT LNG"
            )

            return None

        st.success(
            f"LAT/LNG: {lat}, {lng}"
        )

        return (
            lat,
            lng
        )

    except Exception as e:

        st.error(
            f"DETAIL ERROR: {str(e)}"
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

    origin_location = (
        get_place_location(
            origin_place_id
        )
    )

    destination_location = (
        get_place_location(
            destination_place_id
        )
    )

    if not origin_location:

        st.error(
            "ORIGIN LOCATION FAIL"
        )

        return None

    if not destination_location:

        st.error(
            "DESTINATION LOCATION FAIL"
        )

        return None

    origin_lat, origin_lng = (
        origin_location
    )

    dest_lat, dest_lng = (
        destination_location
    )

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
                    dest_lat,

                    "longitude":
                    dest_lng
                }
            }
        },

        "travelMode":
        travel_mode,

        "computeAlternativeRoutes":
        False
    }

    # =========================
    # 대중교통
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
                "ROUTES API FAILED"
            )

            return None

        data = response.json()

        routes = data.get(
            "routes",
            []
        )

        if not routes:

            st.error(
                "NO ROUTES"
            )

            return None

        duration = routes[0].get(
            "duration"
        )

        if not duration:

            st.error(
                "NO DURATION"
            )

            return None

        seconds = int(
            duration.replace(
                "s",
                ""
            )
        )

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