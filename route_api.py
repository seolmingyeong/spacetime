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

    if not GOOGLE_MAPS_API_KEY:

        st.error(
            "GOOGLE_MAPS_API_KEY 없음"
        )

        return None

    url = (
        "https://maps.googleapis.com/maps/api/distancematrix/json"
    )

    params = {

        "origins":
        f"{start_lat},{start_lng}",

        "destinations":
        f"{end_lat},{end_lng}",

        "mode":
        "driving",

        "key":
        GOOGLE_MAPS_API_KEY
    }

    try:

        response = requests.get(

            url,

            params=params
        )

        data = response.json()

        st.write(
            "Google Status:",
            response.status_code
        )

        st.json(data)

        rows = data.get(
            "rows"
        )

        if not rows:

            return None

        elements = rows[0].get(
            "elements"
        )

        if not elements:

            return None

        element = elements[0]

        if element.get("status") != "OK":

            return None

        duration = element.get(
            "duration"
        )

        if not duration:

            return None

        seconds = duration.get(
            "value"
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