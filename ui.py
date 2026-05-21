import streamlit as st


# =========================
# 추천 장소 카드
# =========================

def render_place_card(place):

    st.markdown(
        f"""
<div style="
padding:28px;
border-radius:20px;
border:1px solid rgba(148,163,184,0.2);
margin-top:30px;
margin-bottom:30px;
backdrop-filter:blur(12px);
">

<div style="
font-size:28px;
font-weight:700;
color:#8b5cf6;
margin-bottom:18px;
">
추천 장소
</div>

<div style="
font-size:22px;
font-weight:600;
margin-bottom:14px;
">
{place["name"]}
</div>

<div style="
opacity:0.8;
margin-bottom:8px;
">
평균 이동시간:
{place["avg_time"]}분
</div>

<div style="
opacity:0.8;
">
최대 이동시간:
{place["max_time"]}분
</div>

</div>
""",
        unsafe_allow_html=True
    )