import requests
import streamlit as st


GOOGLE_API_KEY = (
    st.secrets["GOOGLE_API_KEY"]
    .strip()
)


def search_places(

    lat,
    lng,
    keyword
):

    url = (
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    )

    params = {

        "location":
        f"{lat},{lng}",

        "radius":
        2000,

        "keyword":
        keyword,

        "language":
        "ko",

        "key":
        GOOGLE_API_KEY
    }

    response = requests.get(

        url,

        params=params,

        timeout=10
    )

    data = response.json()

    st.subheader(
        "PLACE SEARCH"
    )

    st.code(data)

    results = data.get(
        "results",
        []
    )

    places = []

    for place in results[:10]:

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
            place.get(
                "name"
            ),

            "lat":
            location.get(
                "lat"
            ),

            "lng":
            location.get(
                "lng"
            ),

            "address":
            place.get(
                "vicinity",
                ""
            ),

            "place_id":
            place.get(
                "place_id"
            )
        })

    return places

def search_place_id(query):

    url = (
        "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
    )

    params = {

        "input":
        query,

        "inputtype":
        "textquery",

        "fields":
        "place_id",

        "language":
        "ko",

        "key":
        GOOGLE_API_KEY
    }

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