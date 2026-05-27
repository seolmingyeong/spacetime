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
margin-bottom:10px;
padding:12px;
border-radius:12px;
background:rgba(148,163,184,0.08);
">

<b>{nickname}</b>

<div style="
margin-top:4px;
opacity:0.8;
">
이동시간:
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
padding:28px;
border-radius:20px;
border:1px solid rgba(148,163,184,0.2);
margin-top:30px;
margin-bottom:30px;
background:rgba(139,92,246,0.08);
">

<div style="
font-size:22px;
font-weight:700;
margin-bottom:14px;
color:#8b5cf6;
">
{place.get("name", "추천 실패")}
</div>

<div style="
opacity:0.8;
margin-bottom:8px;
">
평균 이동시간:
{place.get("avg_time", "-")}분
</div>

<div style="
opacity:0.8;
margin-bottom:20px;
">
최대 이동시간:
{place.get("max_time", "-")}분
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