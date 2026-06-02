import requests
import streamlit as st


# =========================
# 카카오 API 키
# =========================

KAKAO_REST_API_KEY = st.secrets[
    "KAKAO_REST_API_KEY"
]


# =========================
# 장소명 → 좌표 변환
# =========================

def geocode_location(query):

    url = (
        "https://dapi.kakao.com/v2/local/search/keyword.json"
    )
    
    headers = {
        "Authorization": (
            f"KakaoAK {KAKAO_REST_API_KEY}"
        )
    }
    params = {
        "query": query
    }

    response = requests.get(
        url,
        headers=headers,
        params=params
    )

    data = response.json()
    documents = data.get("documents")

    # =========================
    # 검색 실패
    # =========================

    if not documents:
        return None, None, None

    # =========================
    # 첫 검색 결과 사용
    # =========================

    first = documents[0]

    place_name = first["place_name"]

    lat = float(first["y"])
    lng = float(first["x"])

    return place_name, lat, lng

# =========================
# 장소 검색
# =========================

def search_locations(query):

    url = (
        "https://dapi.kakao.com/v2/local/search/keyword.json"
    )

    headers = {
        "Authorization": (
            f"KakaoAK {KAKAO_REST_API_KEY}"
        )
    }

    params = {
        "query": query,
        "size": 5
    }

    response = requests.get(
        url,
        headers=headers,
        params=params
    )

    data = response.json()

    documents = data.get(
        "documents",
        []
    )

    results = []

    for place in documents:

        results.append(
            {
                "name":
                place["place_name"],

                "address":
                place["address_name"],

                "lat":
                float(place["y"]),

                "lng":
                float(place["x"])
            }
        )

    return results