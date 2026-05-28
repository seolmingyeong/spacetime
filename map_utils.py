import folium

import streamlit as st

from streamlit_folium import (
    st_folium
)


# =========================
# 지도 출력
# =========================

def render_map(

    users,

    recommendations,
):

    # =========================
    # 추천 장소 없음
    # =========================

    if not recommendations:

        st.warning(
            "추천 장소가 없습니다."
        )

        return

    # =========================
    # 지도 생성
    # =========================

    m = folium.Map(

        location=[
            recommendations[0]["lat"],
            recommendations[0]["lng"]
        ],

        zoom_start=12,

        tiles="OpenStreetMap",

        control_scale=True
    )

    # =========================
    # 사용자 위치 마커
    # =========================

    for user in users:

        popup_html = f"""
<div style="
width:220px;
">

<div style="
font-size:18px;
font-weight:700;
margin-bottom:8px;
">
{user["nickname"]}
</div>

<div style="
margin-bottom:6px;
">
출발 위치:
{user["location_name"]}
</div>

<div>
이동수단:
{user["transport"]}
</div>

</div>
"""

        folium.CircleMarker(

            location=[
                user["lat"],
                user["lng"]
            ],

            radius=10,

            color="#3b82f6",

            fill=True,

            fill_color="#60a5fa",

            fill_opacity=0.9,

            popup=folium.Popup(
                popup_html,
                max_width=300
            ),

            tooltip=user["nickname"]
        ).add_to(m)

    # =========================
    # 추천 장소 마커
    # =========================

    for place in recommendations:

        # None 방지

        if not place:
            continue

        popup_html = f"""
<div style="
width:240px;
">

<div style="
font-size:18px;
font-weight:700;
margin-bottom:10px;
color:#8b5cf6;
">
{place.get("name", "추천 장소")}
</div>

<div style="
margin-bottom:6px;
">
평균 이동시간:
{place.get("avg_time", "-")}분
</div>

<div>
최대 이동시간:
{place.get("max_time", "-")}분
</div>

</div>
"""

        folium.CircleMarker(

            location=[
                place["lat"],
                place["lng"]
            ],

            radius=14,

            color="#8b5cf6",

            fill=True,

            fill_color="#a78bfa",

            fill_opacity=0.95,

            popup=folium.Popup(
                popup_html,
                max_width=300
            ),

            tooltip=place.get(
                "name",
                "추천 장소"
            )
        ).add_to(m)

    # =========================
    # 지도 출력
    # =========================

    st_folium(

        m,

        height=700,

        use_container_width=True
    )