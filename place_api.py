import requests
import streamlit as st


# =========================
# Kakao API Key
# =========================

KAKAO_REST_API_KEY = st.secrets.get(
    "KAKAO_REST_API_KEY"
)


# =========================
# 장소 검색
# =========================

def search_places(

    lat,
    lng,

    category="카페"
):

    url = (
        "https://dapi.kakao.com/v2/local/search/keyword.json"
    )

    headers = {

        "Authorization":
        f"KakaoAK {KAKAO_REST_API_KEY}"
    }

    params = {

        "query":
        category,

        "x":
        lng,

        "y":
        lat,

        "radius":
        3000,

        "size":
        10
    }

    try:

        response = requests.get(

            url,

            headers=headers,

            params=params,

            timeout=5
        )

        data = response.json()

        documents = data.get(
            "documents",
            []
        )

        places = []

        for place in documents:

            places.append({
                "place_id": place.get("id"),
                "name": place.get("place_name"),
                "address": place.get("road_address_name"),
                "lat": float(place.get("y")),
                "lng": float(place.get("x"))
            })

        return places

    except Exception:

        return []