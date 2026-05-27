import requests
import streamlit as st
from datetime import datetime


# =========================
# API KEY
# =========================

GOOGLE_API_KEY = st.secrets.get(
    "GOOGLE_API_KEY"
)


# =========================
# Routes API 호출
# =========================

def compute_route_duration(

    start_lat,
    start_lng,

    end_lat,
    end_lng,

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

        # 필요한 정보만 요청
        "X-Goog-FieldMask":
        "routes.duration,routes.distanceMeters"
    }

    body = {

        "origin": {

            "location": {

                "latLng": {

                    "latitude":
                    start_lat,

                    "longitude":
                    start_lng
                }
            }
        },

        "destination": {

            "location": {

                "latLng": {

                    "latitude":
                    end_lat,

                    "longitude":
                    end_lng
                }
            }
        },

        "travelMode":
        travel_mode,

        "computeAlternativeRoutes":
        False
    }

    # =========================
    # TRANSIT 설정
    # =========================

    if travel_mode == "TRANSIT":

        body["departureTime"] = (

            datetime.utcnow()

            .isoformat()
            
            + "Z"
        )

    try:

        print(
            "REQUEST:",
            travel_mode
        )

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=10
        )

        data = response.json()

        print(
            "RESPONSE:",
            data
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

        # 예: "1234s"

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

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    return compute_route_duration(

        start_lat,
        start_lng,

        end_lat,
        end_lng,

        "DRIVE"
    )


# =========================
# 도보
# =========================

def get_walk_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    return compute_route_duration(

        start_lat,
        start_lng,

        end_lat,
        end_lng,

        "WALK"
    )


# =========================
# 대중교통
# =========================

def get_transit_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    return compute_route_duration(

        start_lat,
        start_lng,

        end_lat,
        end_lng,

        "TRANSIT"
    )