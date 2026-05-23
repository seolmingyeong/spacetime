import requests
import streamlit as st


# =========================
# Google API Key
# =========================

GOOGLE_MAPS_API_KEY = st.secrets.get(
    "GOOGLE_MAPS_API_KEY"
)


# =========================
# 자동차 이동시간 계산
# =========================

def get_car_travel_time(

    start_lat,
    start_lng,

    end_lat,
    end_lng
):

    if not GOOGLE_MAPS_API_KEY:

        st.error(
            "GOOGLE_MAPS_API_KEY 없음"
        )

        return None

    url = (
        "https://routes.googleapis.com/directions/v2:computeRoutes"
    )

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_MAPS_API_KEY
    }

    # =========================
    # 최소 요청 body
    # =========================

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

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body
        )

        data = response.json()

        # =========================
        # 디버그 출력
        # =========================

        st.write(
            "Google Status:",
            response.status_code
        )

        st.json(data)

        routes = data.get(
            "routes"
        )

        if not routes:

            st.error(
                "routes 없음"
            )

            return None

        route = routes[0]

        duration = route.get(
            "duration"
        )

        if not duration:

            st.error(
                "duration 없음"
            )

            return None

        # 예:
        # "1520s"

        seconds = int(

            duration.replace(
                "s",
                ""
            )
        )

        minutes = int(
            seconds / 60
        )

        return minutes

    except Exception as e:

        st.error(
            f"Google API 오류: {e}"
        )

        return None