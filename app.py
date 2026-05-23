import streamlit as st

from database import *
from recommendation import *
from map_utils import *
from ui import render_place_card

from room import (
    generate_room_code
)

from geopy.geocoders import Nominatim


# =========================
# 페이지 설정
# =========================

st.set_page_config(
    page_title="스페이스타임",
    layout="wide"
)


# =========================
# DB 초기화
# =========================

init_db()


# =========================
# Session State 초기화
# =========================

if "current_room" not in st.session_state:

    st.session_state.current_room = None

if "recommended_places" not in st.session_state:

    st.session_state.recommended_places = []

if "middle_lat" not in st.session_state:

    st.session_state.middle_lat = None

if "middle_lng" not in st.session_state:

    st.session_state.middle_lng = None


# =========================
# 테마 CSS
# =========================

st.markdown(
    """
<style>

.block-container{
    padding-top:2rem;
    padding-bottom:4rem;
}

.main-title{
    font-size:48px;
    font-weight:800;
    margin-bottom:10px;
}

.sub-title{
    font-size:20px;
    color:#64748b;
    margin-bottom:40px;
}

.card{
    padding:24px;
    border-radius:20px;
    border:1px solid rgba(148,163,184,0.2);
    margin-bottom:20px;
}

</style>
""",
    unsafe_allow_html=True
)


# =========================
# 제목
# =========================

st.markdown(
    """
<div class="main-title">
스페이스타임
</div>

<div class="sub-title">
모두의 시간과 공간을 연결하는 약속 플랫폼
</div>
""",
    unsafe_allow_html=True
)


# =========================
# 방 생성 / 입장
# =========================

col1, col2 = st.columns(2)

# =========================
# 방 생성
# =========================

with col1:

    st.markdown(
        "### 방 생성"
    )

    if st.button(
        "새 방 만들기",
        use_container_width=True
    ):

        room_code = generate_room_code()

        st.session_state.current_room = (
            room_code
        )

        st.success(
            f"방 생성 완료: {room_code}"
        )

        st.rerun()


# =========================
# 방 입장
# =========================

with col2:

    st.markdown(
        "### 방 입장"
    )

    room_code_input = st.text_input(
        "방 코드 입력"
    )

    if st.button(
        "방 입장",
        use_container_width=True
    ):

        room_code = room_code_input.strip()

        # =========================
        # 입력 없음
        # =========================

        if not room_code:

            st.error(
                "방 코드를 입력하세요."
            )

        # =========================
        # 방 존재 확인
        # =========================

        elif not room_exists(room_code):

            st.error(
                "존재하지 않는 방입니다."
            )

        # =========================
        # 정상 입장
        # =========================

        else:

            st.session_state.current_room = (
                room_code
            )

            st.success(
                f"{room_code} 방에 입장했습니다."
            )

            st.rerun()


# =========================
# 현재 방 표시
# =========================

if st.session_state.current_room:

    st.markdown(
        f"""
<div class="card">

<h3>
현재 방
</h3>

<p>
{st.session_state.current_room}
</p>

</div>
""",
        unsafe_allow_html=True
    )


# =========================
# 사용자 정보 입력
# =========================

if st.session_state.current_room:

    st.markdown(
        "## 사용자 정보 입력"
    )

    nickname = st.text_input(
        "닉네임"
    )

    location_name = st.text_input(
        "출발 위치"
    )

    transport = st.selectbox(

        "이동수단",

        [
            "자동차"
        ]
    )

    # =========================
    # 날짜 선택
    # =========================

    selected_dates = st.date_input(
        "가능한 날짜",
        value=[]
    )

    # =========================
    # 저장 버튼
    # =========================

    if st.button(
        "정보 저장",
        use_container_width=True
    ):

        # =========================
        # 입력 확인
        # =========================

        if not nickname:

            st.error(
                "닉네임을 입력하세요."
            )

        elif not location_name:

            st.error(
                "출발 위치를 입력하세요."
            )

        else:

            try:

                geolocator = Nominatim(
                    user_agent="spacetime"
                )

                location = geolocator.geocode(
                    location_name
                )

                # =========================
                # 위치 실패
                # =========================

                if not location:

                    st.error(
                        "위치를 찾을 수 없습니다."
                    )

                else:

                    lat = location.latitude
                    lng = location.longitude

                    dates_text = ",".join(

                        [
                            str(d)
                            for d in selected_dates
                        ]
                    )

                    save_user(

                        st.session_state.current_room,

                        nickname,

                        dates_text,

                        location_name,

                        lat,

                        lng,

                        transport
                    )

                    st.success(
                        "정보 저장 완료"
                    )

                    st.rerun()

            except Exception:

                st.error(
                    "위치를 찾을 수 없습니다."
                )


# =========================
# 참가자 목록
# =========================

if st.session_state.current_room:

    users_data = get_room_users(

        st.session_state.current_room
    )

    users = []

    for user in users_data:

        users.append({

            "id":
            user[0],

            "room_id":
            user[1],

            "nickname":
            user[2],

            "dates":
            user[3],

            "location_name":
            user[4],

            "lat":
            user[5],

            "lng":
            user[6],

            "transport":
            user[7]
        })

    # =========================
    # 참가자 출력
    # =========================

    if len(users) > 0:

        st.markdown(
            "## 참가자 목록"
        )

        for user in users:

            st.markdown(
                f"""
<div class="card">

<h3>
{user["nickname"]}
</h3>

<p>
출발 위치:
{user["location_name"]}
</p>

<p>
이동수단:
{user["transport"]}
</p>

<p>
가능 날짜:
{user["dates"]}
</p>

</div>
""",
                unsafe_allow_html=True
            )

    # =========================
    # 추천 장소 찾기
    # =========================

    if len(users) >= 2:

        if st.button(
            "추천 장소 찾기",
            use_container_width=True
        ):

            middle_lat, middle_lng = (

                get_middle_point(
                    users
                )
            )

            st.session_state.middle_lat = (
                middle_lat
            )

            st.session_state.middle_lng = (
                middle_lng
            )

            recommended_places = (

                recommend_places(

                    users,

                    middle_lat,
                    middle_lng
                )
            )

            st.session_state.recommended_places = (
                recommended_places
            )

            st.rerun()


# =========================
# 추천 장소 출력
# =========================

if st.session_state.recommended_places:

    st.markdown(
        "## 추천 장소"
    )

    for place in st.session_state.recommended_places:

        render_place_card(
            place
        )


# =========================
# 지도 출력
# =========================

if (

    st.session_state.recommended_places

    and

    st.session_state.middle_lat
    is not None

    and

    st.session_state.middle_lng
    is not None
):

    users_data = get_room_users(

        st.session_state.current_room
    )

    users = []

    for user in users_data:

        users.append({

            "nickname":
            user[2],

            "location_name":
            user[4],

            "lat":
            user[5],

            "lng":
            user[6],

            "transport":
            user[7]
        })

    st.markdown(
        "## 지도"
    )

    render_map(

        users,

        st.session_state.recommended_places,

        st.session_state.middle_lat,

        st.session_state.middle_lng
    )