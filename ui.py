import streamlit as st


def render_place_card(place):

    st.markdown(
        f"""
<div style="
background:#1e293b;
padding:24px;
border-radius:20px;
border:2px solid #22c55e;
margin-bottom:20px;
">

<h1 style="
color:#22c55e;
">
🌟 추천 장소
</h1>

<h2 style="
color:white;
">
{place["name"]}
</h2>

<p style="
color:#d1fae5;
">
⏱ 평균 이동시간:
{place["avg_time"]}분
</p>

<p style="
color:#d1fae5;
">
📍 {place["address"]}
</p>

</div>
""",
        unsafe_allow_html=True
    )