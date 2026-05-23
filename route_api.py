import requests
import streamlit as st


GOOGLE_MAPS_API_KEY = st.secrets.get(
    "GOOGLE_MAPS_API_KEY"
)


def get_car_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    url = (
        "https://routes.googleapis.com/directions/v2:computeRoutes"
    )

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_MAPS_API_KEY,

        # 중요
        "X-Goog-FieldMask":
        "routes.duration"
    }

    body = {

        "origin": {

            "location": {

                "latLng": {

                    "latitude":
                    float(start_lat),

                    "longitude":
                    float(start_lng)
                }
            }
        },

        "destination": {

            "location": {

                "latLng": {

                    "latitude":
                    float(end_lat),

                    "longitude":
                    float(end_lng)
                }
            }
        },

        "travelMode":
        "DRIVE"
    }

    response = requests.post(

        url,

        headers=headers,

        json=body
    )

    data = response.json()

    st.write(
        "Google Status:",
        response.status_code
    )

    st.json(data)

    routes = data.get(
        "routes"
    )

    if not routes:

        return None

    duration = routes[0].get(
        "duration"
    )

    if not duration:

        return None

    seconds = int(
        duration.replace(
            "s",
            ""
        )
    )

    return int(seconds / 60)