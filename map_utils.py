import folium

from streamlit_folium import (
    st_folium
)


def render_map(
    users,
    recommendations,
    middle_lat,
    middle_lng
):

    m = folium.Map(

        location=[
            middle_lat,
            middle_lng
        ],

        zoom_start=13,

        tiles="CartoDB dark_matter",

        scrollWheelZoom=False
    )

    for user in users:

        folium.Marker(

            [
                user["lat"],
                user["lng"]
            ],

            popup=user["nickname"],

            tooltip=user["nickname"]

        ).add_to(m)

    for place in recommendations:

        folium.Marker(

            [
                place["lat"],
                place["lng"]
            ],

            popup=place["name"]

        ).add_to(m)

    st_folium(
        m,
        height=700,
        use_container_width=True
    )