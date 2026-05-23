import streamlit as st


# =========================
# 추천 장소 카드
# =========================

def render_place_card(place):

    # =========================
    # 추천 실패
    # =========================

    if not place:

        st.error(
            "추천 장소를 계산할 수 없습니다."
        )

        return

    # =========================
    # user_times 안전 처리
    # =========================

    user_times = place.get(
        "user_times",
        []
    )

    users_html = ""

    # =========================
    # 참가자 이동시간 출력
    # =========================

    for user in user_times:

        nickname = user.get(
            "nickname",
            "-"
        )

        travel_time = user.get(
            "travel_time",
            "-"
        )

        users_html += f"""

<div style="
margin-bottom:12px;
padding:14px;
border-radius:14px;
background:rgba(255,255,255,0.05);
display:flex;
justify-content:space-between;
align-items:center;
">

<div style="
font-weight:600;
">
{nickname}
</div>

<div style="
font-weight:700;
color:#c4b5fd;
">
{travel_time}분
</div>

</div>
"""

    # =========================
    # 카드 출력
    # =========================

    st.markdown(
        f"""
<div style="

padding:32px;

border-radius:24px;

background:
linear-gradient(
    135deg,
    rgba(139,92,246,0.18),
    rgba(96,165,250,0.12)
);

border:2px solid rgba(139,92,246,0.4);

margin-top:24px;

margin-bottom:32px;

box-shadow:
0 8px 30px rgba(139,92,246,0.15);

">

<div style="
font-size:28px;
font-weight:800;
margin-bottom:14px;
color:#ddd6fe;
">
{place.get("name", "추천 실패")}
</div>

<div style="
opacity:0.75;
margin-bottom:20px;
font-size:15px;
">
{place.get("address", "")}
</div>

<div style="
display:flex;
gap:16px;
flex-wrap:wrap;
margin-bottom:22px;
">

<div style="
padding:12px 18px;
border-radius:14px;
background:rgba(139,92,246,0.18);
font-weight:600;
">

평균 이동시간:
{place.get("avg_time", "-")}분

</div>

<div style="
padding:12px 18px;
border-radius:14px;
background:rgba(96,165,250,0.18);
font-weight:600;
">

최대 이동시간:
{place.get("max_time", "-")}분

</div>

</div>

<div style="
font-size:18px;
font-weight:700;
margin-bottom:14px;
">
참가자별 이동시간
</div>

{users_html}

</div>
""",
        unsafe_allow_html=True
    )