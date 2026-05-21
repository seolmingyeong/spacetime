import folium

from streamlit_folium import (
    st_folium
)


# =========================
# 지도 출력
# =========================

def render_map(
    users,
    recommendations,
    middle_lat,
    middle_lng
):

    if middle_lat is None:
        return

    # =========================
    # 지도 생성
    # =========================

    m = folium.Map(

        location=[
            middle_lat,
            middle_lng
        ],

        zoom_start=12,

        tiles="OpenStreetMap",

        scrollWheelZoom=True
    )

    # =========================
    # 사용자 위치
    # =========================

    for user in users:

        if (
            user["lat"] is None
            or user["lng"] is None
        ):
            continue

        popup_html = f"""

        <div style="
        width:220px;
        ">

            <div style="
            font-size:18px;
            font-weight:700;
            margin-bottom:10px;
            color:#2563eb;
            ">
            {user["nickname"]}
            </div>

            <div style="
            margin-bottom:6px;
            ">
            출발 위치:
            {user.get("location_name", "-")}
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

            color="#60a5fa",

            fill=True,

            fill_color="#60a5fa",

            fill_opacity=0.9,

            popup=folium.Popup(
                popup_html,
                max_width=260
            ),

            tooltip=user["nickname"]

        ).add_to(m)

    # =========================
    # 추천 장소
    # =========================

    for place in recommendations:

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
            {place["name"]}
            </div>

            <div style="
            margin-bottom:6px;
            ">
            평균 이동시간:
            {place["avg_time"]}분
            </div>

            <div>
            최대 이동시간:
            {place["max_time"]}분
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

            fill_color="#8b5cf6",

            fill_opacity=1,

            popup=folium.Popup(
                popup_html,
                max_width=280
            ),

            tooltip=place["name"]

        ).add_to(m)

    # =========================
    # 지도 출력
    # =========================

    st_folium(

        m,

        height=720,

        use_container_width=True
    )