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

    # =========================
    # API 키 없음
    # =========================

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
        GOOGLE_MAPS_API_KEY,

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
        "DRIVE"
    }

    try:

        response = requests.post(

            url,

            headers=headers,

            json=body
        )

        # =========================
        # 디버그 출력
        # =========================

        st.write(
            "Google Status:",
            response.status_code
        )

        st.write(
            response.text
        )

        data = response.json()

        routes = data.get(
            "routes"
        )

        # =========================
        # routes 없음
        # =========================

        if not routes:

            st.error(
                "routes 없음"
            )

            return None

        duration = routes[0][
            "duration"
        ]

        # 예:
        # "1320s"

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