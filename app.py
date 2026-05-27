# =========================
# app.py
# =========================

import random
import string

from datetime import date

import streamlit as st

from database import *
from recommendation import *
from route_api import *
from map_utils import *
from ui import *

from theme import apply_theme
from geo import geocode_location
from route_api import ( get_station_place_id )
from place_api import ( search_places )

# =========================
# 페이지 설정
# =========================

st.set_page_config(

    page_title="스페이스타임",

    layout="wide"
)


# =========================
# 테마 적용
# =========================

apply_theme()


# =========================
# DB 초기화
# =========================

init_db()


# =========================
# session state
# =========================

if "current_room" not in st.session_state:

    st.session_state.current_room = None


if "recommendations" not in st.session_state:

    st.session_state.recommendations = None


if "nickname" not in st.session_state:

    st.session_state.nickname = ""


if "selected_dates" not in st.session_state:

    st.session_state.selected_dates = []


if "save_success" not in st.session_state:

    st.session_state.save_success = False


# =========================
# 제목
# =========================

st.markdown(
    """
<h1 style="
text-align:center;
font-size:58px;
font-weight:800;
background:
linear-gradient(
    90deg,
    #8b5cf6,
    #60a5fa
);
-webkit-background-clip:text;
-webkit-text-fill-color:transparent;
margin-bottom:10px;
">
스페이스타임
</h1>

<p style="
text-align:center;
font-size:18px;
margin-bottom:35px;
opacity:0.8;
">
모두의 시간과 공간을 연결하는 약속 플랫폼
</p>
""",
    unsafe_allow_html=True
)


# =========================
# 시작 화면
# =========================

if not st.session_state.current_room:

    col1, col2 = st.columns(2)

    # =========================
    # 방 만들기
    # =========================

    with col1:

        st.markdown(
            """
<div class="card">

<h3>
새 방 만들기
</h3>

<p>
새로운 약속 공간 생성
</p>

</div>
""",
            unsafe_allow_html=True
        )

        if st.button(
            "방 만들기",
            key="create_room"
        ):

            # =========================
            # 중복 없는 방 코드 생성
            # =========================

            while True:

                room_id = "".join(

                    random.choices(

                        string.ascii_uppercase
                        + string.digits,

                        k=6
                    )
                )

                # =========================
                # 중복 방지
                # =========================

                if not room_exists(room_id):

                    break

            st.session_state.current_room = (
                room_id
            )

            st.rerun()

    # =========================
    # 방 입장
    # =========================

    with col2:

        st.markdown(
            """
<div class="card">

<h3>
방 입장
</h3>

<p>
기존 약속 공간 참여
</p>

</div>
""",
            unsafe_allow_html=True
        )

        join_room = st.text_input(
            "방 코드 입력"
        )

        if st.button(
            "입장하기",
            key="join_room"
        ):

            join_room = join_room.strip()

            # =========================
            # 입력 없음
            # =========================

            if not join_room:

                st.error(
                    "방 코드를 입력하세요."
                )

            # =========================
            # 존재하지 않는 방
            # =========================

            elif not room_exists(join_room):

                st.error(
                    "존재하지 않는 방입니다."
                )

            # =========================
            # 정상 입장
            # =========================

            else:

                st.session_state.current_room = (
                    join_room
                )

                st.rerun()

# =========================
# 방 입장 후
# =========================

else:

    st.markdown(
        f"""
<div class="card">

<h2>
방 코드:
{st.session_state.current_room}
</h2>

</div>
""",
        unsafe_allow_html=True
    )

    # =========================
    # 사용자 정보 입력
    # =========================

    st.markdown(
        """
<h3 style="
margin-top:20px;
margin-bottom:20px;
">
내 정보 입력
</h3>
""",
        unsafe_allow_html=True
    )

    col1, col2 = st.columns(2)

    with col1:

        nickname = st.text_input(

            "닉네임",

            value=st.session_state.nickname
        )

        location_name = st.text_input(
            "출발 위치"
        )

    with col2:

        transport = st.selectbox(

            "이동수단",

            [
                "도보",
                "대중교통",
                "자동차"
            ]
        )

    # =========================
    # 가능한 날짜
    # =========================

    st.markdown(
        """
<h3 style="
margin-top:30px;
margin-bottom:20px;
font-size:24px;
font-weight:700;
">
가능한 날짜
</h3>
""",
        unsafe_allow_html=True
    )

    selected_date = st.date_input(

        "날짜 선택",

        value=None,

        min_value=date.today()
    )

    # =========================
    # 날짜 추가 버튼
    # =========================

    if st.button(
        "날짜 추가",
        key="add_date_button"
    ):

        if selected_date:

            date_str = selected_date.strftime(
                "%Y-%m-%d"
            )

            if (
                date_str
                not in
                st.session_state.selected_dates
            ):

                st.session_state.selected_dates.append(
                    date_str
                )

                st.rerun()

    # =========================
    # 선택된 날짜 목록
    # =========================

    if st.session_state.selected_dates:

        st.markdown(
            """
<h4 style="
margin-top:20px;
margin-bottom:12px;
">
선택된 날짜
</h4>
""",
            unsafe_allow_html=True
        )

        for idx, d in enumerate(

            sorted(
                st.session_state.selected_dates
            )
        ):

            col1, col2 = st.columns(
                [8, 1]
            )

            with col1:

                st.markdown(
                    f"""
<div style="
padding:14px;
margin-bottom:10px;
background:
linear-gradient(
    90deg,
    #8b5cf6,
    #60a5fa
);
color:white;
font-weight:700;
border-radius:12px;
">
{d}
</div>
""",
                    unsafe_allow_html=True
                )

            with col2:

                if st.button(

                    "삭제",

                    key=f"remove_date_{idx}"
                ):

                    st.session_state.selected_dates.remove(
                        d
                    )

                    st.rerun()

    # =========================
    # 저장 버튼
    # =========================

    if st.button(

        "정보 저장",

        key=f"save_user_{st.session_state.current_room}"
    ):

        if not nickname.strip():

            st.error(
                "닉네임을 입력하세요."
            )

        elif not location_name.strip():

            st.error(
                "출발 위치를 입력하세요."
            )

        else:

            # =========================
            # 장소 검색
            # =========================

            place_name, lat, lng = (
                geocode_location(
                    location_name.strip()
                )
            )

        # =========================
        # Google Place ID
        # =========================

        try:

            place_id = (
                get_station_place_id(
                    location_name.strip()
                )
            )

        except Exception as e:

            st.warning(
                f"PLACE_ID 생성 실패: {str(e)}"
            )

            place_id = None


        # =========================
        # PLACE_ID 실패해도 저장 진행
        # =========================

        if place_id is None:

            st.warning(
                "Google Place ID 없이 저장합니다."
            )


        # =========================
        # 사용자 저장
        # =========================

        save_user(

            st.session_state.current_room,

            nickname,

            ",".join(
                st.session_state.selected_dates
            ),

            place_name,

            lat,

            lng,

            place_id,

            transport
        )

        st.success(
            "정보 저장 완료!"
        )

    # =========================
    # 참가자 목록
    # =========================

    users_data = get_room_users(

        st.session_state.current_room
    )

    # =========================
    # 참가자 존재 시만 출력
    # =========================

    if len(users_data) > 0:

        st.markdown(
            """
    <h2 style="
    margin-top:40px;
    margin-bottom:20px;
    ">
    참가자
    </h2>
    """,
            unsafe_allow_html=True
        )

        for user in users_data:

            st.markdown(
                f"""
    <div class="card">

    <div style="
    font-size:22px;
    font-weight:700;
    color:#8b5cf6;
    margin-bottom:10px;
    ">
    {user[2]}
    </div>

    <div style="
    margin-bottom:6px;
    opacity:0.85;
    ">
    {user[4]}
    </div>

    <div style="
    margin-bottom:6px;
    opacity:0.85;
    ">
    {user[7]}
    </div>

    <div style="
    opacity:0.85;
    ">
    {user[3]}
    </div>

    </div>
    """,
                unsafe_allow_html=True
            )
    # =========================
    # 추천 장소 버튼
    # =========================

    if len(users_data) >= 2:

        if st.button(
            "추천 장소 찾기",
            key="recommend_button"
        ):

            with st.spinner(
                "추천 장소를 찾는 중..."
            ):

                # =========================
                # 지도용 사용자 데이터
                # =========================

                users = []

                for user in users_data:

                    users.append({

                        "nickname": user[2],

                        "address": user[4],

                        "location_name": user[4],

                        "lat": user[5],

                        "lng": user[6],

                        "place_id": user[7],

                        "transport": user[8]
                    })

                # =========================
                # 추천 장소 계산
                # =========================

                st.write("recommend 시작")
                recommendations = (
                    recommend_places(
                        users
                    )
                )
                st.write("recommend 끝")  

                # =========================
                # session 저장
                # =========================

                st.session_state.recommendations = (
                    recommendations
                )

    # =========================
    # 추천 결과
    # =========================

    if st.session_state.recommendations:

        recommendations = (
            st.session_state.recommendations
        )

        st.markdown(
            """
    <h2 style="
    margin-top:40px;
    margin-bottom:20px;
    ">
    추천 장소
    </h2>
    """,
            unsafe_allow_html=True
        )

        # =========================
        # 추천 장소 여러 개 출력
        # =========================

        for idx, place in enumerate(
            recommendations
        ):

            st.markdown(
                f"""
    <h3 style="
    margin-top:25px;
    margin-bottom:10px;
    color:#8b5cf6;
    ">
    #{idx + 1} 추천
    </h3>
    """,
                unsafe_allow_html=True
            )

            render_place_card(
                place
            )
            
    
        # =========================
        # 지도용 사용자 데이터
        # =========================

        users = []

        for user in users_data:

            users.append({

                "nickname": user[2],

                "address": user[4],

                "location_name": user[4],

                "lat": user[5],

                "lng": user[6],

                "place_id": user[7],

                "transport": user[8]
            })

        # =========================
        # 지도 제목
        # =========================

        st.markdown(
            """
    <h2 style="
    margin-top:40px;
    margin-bottom:20px;
    ">
    지도
    </h2>
    """,
            unsafe_allow_html=True
        )

        # =========================
        # 지도 출력
        # =========================

        render_map(

            users,

            recommendations
        )

# =========================
# DEBUG LOGS
# =========================

if "debug_logs" in st.session_state:

    st.subheader("DEBUG LOGS")

    for log in st.session_state.debug_logs:

        st.code(log)
