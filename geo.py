import requests
import streamlit as st


# =========================
# 카카오 API 키
# =========================

KAKAO_REST_API_KEY = st.secrets[
    "KAKAO_REST_API_KEY"
]


# =========================
# 주소 → 좌표 변환
# =========================

def geocode_location(query):

    url = (
        "https://dapi.kakao.com/v2/local/search/address.json"
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
    # 주소 검색 실패 시
    # 키워드 검색
    # =========================

    if not documents:

        url = (
            "https://dapi.kakao.com/v2/local/search/keyword.json"
        )

        response = requests.get(

            url,

            headers=headers,

            params=params
        )

        data = response.json()

        documents = data.get("documents")

        if not documents:

            return None, None

    first = documents[0]

    lat = float(first["y"])
    lng = float(first["x"])

    return lat, lng