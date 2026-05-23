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
    # API 키 확인
    # =========================

    if not GOOGLE_MAPS_API_KEY:

        st.error(
            "GOOGLE_MAPS_API_KEY 없음"
        )

        return None

    # =========================
    # Google Routes API URL
    # =========================

    url = (
        "https://routes.googleapis.com/directions/v2:computeRoutes"
    )

    # =========================
    # 요청 헤더
    # =========================

    headers = {

        "Content-Type":
        "application/json",

        "X-Goog-Api-Key":
        GOOGLE_MAPS_API_KEY,

        "X-Goog-FieldMask":
        "routes.duration"
    }

    # =========================
    # 요청 body
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

        # =========================
        # routes 확인
        # =========================

        routes = data.get(
            "routes"
        )

        if not routes:

            st.error(
                "routes 없음"
            )

            return None

        route = routes[0]

        # =========================
        # duration 확인
        # =========================

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