import folium
import streamlit as st

from pathlib import Path
from folium.features import DivIcon
from streamlit_folium import st_folium


# =========================
# 지도 출력
# =========================

def render_map(

    users,

    recommendations
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
    # 지도 중심 계산
    # =========================

    try:

        center_lat = (

            sum(
                float(user["lat"])
                for user in users
            )

            / len(users)
        )

        center_lng = (

            sum(
                float(user["lng"])
                for user in users
            )

            / len(users)
        )

    except Exception:

        center_lat = (
            float(
                recommendations[0]["lat"]
            )
        )

        center_lng = (
            float(
                recommendations[0]["lng"]
            )
        )

    # =========================
    # 지도 생성
    # =========================

    m = folium.Map(

        location=[
            center_lat,
            center_lng
        ],

        zoom_start=12,

        tiles="OpenStreetMap",

        control_scale=True
    )

    # =========================
    # 사용자 이미지 경로
    # =========================

    BASE_DIR = Path(__file__).resolve().parent

    user_icons = [

        str(BASE_DIR / "p1.png"),

        str(BASE_DIR / "p2.png"),

        str(BASE_DIR / "p3.png")
    ]

    # =========================
    # 사용자 위치 마커
    # =========================

    for idx, user in enumerate(users):

        popup_html = f"""
<div style="
width:220px;
">

<div style="
font-size:18px;
font-weight:700;
margin-bottom:8px;
">
{user.get("nickname", "사용자")}
</div>

<div style="
margin-bottom:6px;
">
출발 위치:
{user.get("location_name", "-")}
</div>

<div>
이동수단:
{user.get("transport", "-")}
</div>

</div>
"""

        try:

            icon_path = user_icons[
                idx % len(user_icons)
            ]

            custom_icon = folium.CustomIcon(

                icon_image=icon_path,

                icon_size=(40, 40)
            )

            folium.Marker(

                location=[
                    float(user["lat"]),
                    float(user["lng"])
                ],

                icon=custom_icon,

                popup=folium.Popup(
                    popup_html,
                    max_width=300
                ),

                tooltip=user.get(
                    "nickname",
                    "사용자"
                )

            ).add_to(m)

        except Exception:

            # 이미지 로드 실패 시 대체 마커

            folium.CircleMarker(

                location=[
                    float(user["lat"]),
                    float(user["lng"])
                ],

                radius=12,

                color="#2563eb",

                fill=True,

                fill_color="#60a5fa",

                fill_opacity=1.0,

                popup=folium.Popup(
                    popup_html,
                    max_width=300
                )

            ).add_to(m)

    # =========================
    # 추천 장소 마커
    # =========================

    medals = [

        "🥇",

        "🥈",

        "🥉"
    ]

    for rank, place in enumerate(recommendations):

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
#{rank + 1}
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

        medal = (

            medals[rank]

            if rank < 3

            else "🏅"
        )

        size = (

            60

            if rank == 0

            else 42
        )

        folium.Marker(

            location=[
                float(place["lat"]),
                float(place["lng"])
            ],

            icon=DivIcon(
                html=f"""
<div style="
font-size:{size}px;
text-align:center;
line-height:1;
">
{medal}
</div>
"""
            ),

            popup=folium.Popup(
                popup_html,
                max_width=300
            ),

            tooltip=f"{rank + 1}순위 추천 장소"

        ).add_to(m)

    # =========================
    # 화면에 모두 보이도록 자동 조정
    # =========================

    bounds = []

    for user in users:

        try:

            bounds.append([

                float(user["lat"]),

                float(user["lng"])
            ])

        except Exception:

            pass

    for place in recommendations:

        try:

            bounds.append([

                float(place["lat"]),

                float(place["lng"])
            ])

        except Exception:

            pass

    if bounds:

        m.fit_bounds(bounds)

    # =========================
    # 지도 출력
    # =========================

    st_folium(

        m,

        height=700,

        use_container_width=True
    )