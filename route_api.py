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
# ROUTE CACHE
# =========================

route_cache = {}


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

        candidates = data.get(
            "candidates",
            []
        )

        if not candidates:

            return None

        return candidates[0].get(
            "place_id"
        )

    except:

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

        result = data.get(
            "result"
        )

        if not result:

            return None

        location = (
            result["geometry"]["location"]
        )

        return (
            location["lat"],
            location["lng"]
        )

    except:

        return None


# =========================
# 이동수단 변환
# =========================

def convert_travel_mode(mode):

    if mode == "도보":

        return "WALK"

    elif mode == "자동차":

        return "DRIVE"

    elif mode == "대중교통":

        return "TRANSIT"

    return mode


# =========================
# Routes API
# =========================

def compute_route_duration(

    origin_place_id,

    destination_place_id,

    travel_mode
):

    travel_mode = convert_travel_mode(
        travel_mode
    )

    # =========================
    # CACHE
    # =========================

    cache_key = (

        origin_place_id,

        destination_place_id,

        travel_mode
    )

    if cache_key in route_cache:

        return route_cache[
            cache_key
        ]

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

        route_cache[
            cache_key
        ] = None

        return None

    if not destination_location:

        route_cache[
            cache_key
        ] = None

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
        GOOGLE_API_KEY
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
        travel_mode
    }

    # =========================
    # TRANSIT 전용
    # =========================

    if travel_mode == "TRANSIT":

        body["departureTime"] = (

            datetime.utcnow()

            .replace(microsecond=0)

            .isoformat()

            + "Z"
        )

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=20
        )

        if response.status_code != 200:

            route_cache[
                cache_key
            ] = None

            return None

        data = response.json()

        routes = data.get(
            "routes",
            []
        )

        if not routes:

            route_cache[
                cache_key
            ] = None

            return None

        route = routes[0]

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

        if not duration:

            route_cache[
                cache_key
            ] = None

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

        route_cache[
            cache_key
        ] = minutes

        return minutes

    except:

        route_cache[
            cache_key
        ] = None

        return None


# =========================
# 자동차
# =========================

def get_car_travel_time(

    origin_place_id,

    destination_place_id
):

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

    user_place_id,

    candidate_place_id
):

    return compute_route_duration(

        user_place_id,

        candidate_place_id,

        "TRANSIT"
    )