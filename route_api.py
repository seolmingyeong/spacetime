import requests
import streamlit as st


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

        # duration만 받기
        "X-Goog-FieldMask":
        "routes.duration"
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
        travel_mode
    }

    # =========================
    # 대중교통 옵션
    # =========================

    if travel_mode == "TRANSIT":

        body["computeAlternativeRoutes"] = False

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body,

            timeout=5
        )

        data = response.json()

        routes = data.get(
            "routes",
            []
        )

        if not routes:

            return None

        duration_str = routes[0].get(
            "duration"
        )

        if not duration_str:

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

        return minutes

    except Exception:

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