import requests
import streamlit as st


# =========================
# API KEY
# =========================

GOOGLE_API_KEY = st.secrets.get(
    "GOOGLE_API_KEY"
)


# =========================
# Google Nearby Search
# =========================

def search_places(

    lat,
    lng,

    keyword="cafe"
):

    url = (
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    )

    params = {

        "location":
        f"{lat},{lng}",

        "radius":
        4000,

        "keyword":
        keyword,

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

        st.write(
            "PLACE SEARCH:",
            data
        )

        results = data.get(
            "results",
            []
        )

        places = []

        for place in results:

            geometry = place.get(
                "geometry",
                {}
            )

            location = geometry.get(
                "location",
                {}
            )

            places.append({

                "name":
                place.get("name"),

                "address":
                place.get(
                    "vicinity",
                    ""
                ),

                "lat":
                location.get("lat"),

                "lng":
                location.get("lng"),

                "place_id":
                place.get("place_id")
            })

        return places

    except Exception as e:

        st.write(
            "PLACE ERROR:",
            str(e)
        )

        return []