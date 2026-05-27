import requests
import streamlit as st

from datetime import datetime
import json


# =========================
# API KEY
# =========================

GOOGLE_API_KEY = st.secrets.get(
    "GOOGLE_API_KEY"
)


# =========================
# Google Place ID 검색
# =========================

def get_google_place_id(query):

    query = query + " 서울"

    url = (
        "https://places.googleapis.com/v1/places:searchText"
    )

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_API_KEY,

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

        print(
            "PLACE STATUS:",
            response.status_code
        )

        print(
    "RAW TEXT:"
        )

        print(
            response.text
        )

        data = response.json()



        print(
            json.dumps(
                data,
                indent=2,
                ensure_ascii=False
            )
        )

        places = data.get(
            "places",
            []
        )

        if not places:

            print(
                "NO PLACES"
            )

            return None

        place_id = places[0].get(
            "id"
        )

        print(
            "PLACE_ID:",
            place_id
        )

        return place_id

    except Exception as e:

        print(
            "PLACE ERROR:",
            str(e)
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
    # TRANSIT 옵션
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

        print(
            "REQUEST MODE:",
            travel_mode
        )

        print(
            "REQUEST BODY:",
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

        print(
            "ROUTE STATUS:",
            response.status_code
        )

        data = response.json()

        print(
            json.dumps(
                data,
                indent=2,
                ensure_ascii=False
            )
        )

        routes = data.get(
            "routes",
            []
        )

        if not routes:

            print(
                "NO ROUTES"
            )

            return None

        duration_str = routes[0].get(
            "duration"
        )

        if not duration_str:

            print(
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

        print(
            "MINUTES:",
            minutes
        )

        return minutes

    except Exception as e:

        print(
            "ROUTE ERROR:",
            str(e)
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

    print(
        "CAR PLACE IDS:",
        origin_place_id,
        destination_place_id
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

    print(
        "WALK PLACE IDS:",
        origin_place_id,
        destination_place_id
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

    print(
        "TRANSIT PLACE IDS:",
        origin_place_id,
        destination_place_id
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