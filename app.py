import uuid
import streamlit as st
import folium
from streamlit_calendar import calendar

from streamlit_folium import st_folium

from database import (
    init_db,
    create_room,
    room_exists,
    save_user,
    get_room_users
)

from map_utils import (
    search_location,
    get_middle_point
)

from recommendation import recommend_places
from scoring import get_route_time



# =========================
# 초기 설정
# =========================

init_db()

st.set_page_config(
    page_title="AI 약속 장소 추천 시스템",
    layout="wide"
)

# =========================
# CSS
# =========================

st.markdown(
    """
    <style>

    .stApp {
        background-color: #0f172a;
        color: #f8fafc;
    }

    section[data-testid="stSidebar"] {
        background-color: #111827;
    }

    h1, h2, h3, h4, h5, h6, p, label {
        color: #f8fafc !important;
    }

    div[data-testid="stTextInput"] input {
        background-color: #1e293b !important;
        color: white !important;
        border-radius: 12px;
        border: 1px solid #334155;
    }

    div[data-testid="stSelectbox"] > div {
        background-color: #1e293b !important;
        color: white !important;
        border-radius: 12px;
    }

    div[data-testid="stDateInput"] input {
        background-color: #1e293b !important;
        color: white !important;
        border-radius: 12px;
    }

    .stButton > button {

        background: linear-gradient(
            135deg,
            #166534,
            #15803d
        );

        color: white;

        border: none;

        border-radius: 14px;

        padding: 0.6rem 1.2rem;

        font-weight: bold;

        transition: 0.3s;
    }

    .stButton > button:hover {

        background: linear-gradient(
            135deg,
            #15803d,
            #22c55e
        );

        transform: scale(1.03);
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
    <div style="
        font-size:3rem;
        font-weight:800;
        color:#22c55e;
        margin-bottom:10px;
    ">
        AI 약속 장소 추천 시스템
    </div>

    <div style="
        color:#cbd5e1;
        margin-bottom:30px;
        font-size:1.1rem;
    ">
        일정 · 위치 · 이동수단 기반
        최적 약속 장소 추천 플랫폼
    </div>
    """,
    unsafe_allow_html=True
)

# =========================
# session state
# =========================

if "current_room" not in st.session_state:
    st.session_state.current_room = None

if "selected_dates" not in st.session_state:
    st.session_state.selected_dates = []

if "recommendations" not in st.session_state:
    st.session_state.recommendations = None

if "middle_lat" not in st.session_state:
    st.session_state.middle_lat = None

if "middle_lng" not in st.session_state:
    st.session_state.middle_lng = None

# =========================
# 사이드바
# =========================

st.sidebar.title("메뉴")

if st.sidebar.button("새 방 만들기"):

    room_id = str(uuid.uuid4())[:8]

    create_room(room_id)

    st.session_state.current_room = room_id

    st.session_state.selected_dates = []

    st.session_state.recommendations = None

room_input = st.sidebar.text_input(
    "방 코드 입력"
)

if st.sidebar.button("방 참가"):

    if room_exists(room_input):

        st.session_state.current_room = room_input

        st.session_state.selected_dates = []

        st.session_state.recommendations = None

    else:

        st.sidebar.error(
            "존재하지 않는 방입니다"
        )

# =========================
# 메인
# =========================

if st.session_state.current_room:

    room_id = st.session_state.current_room

    st.success(f"현재 방: {room_id}")

    nickname = st.text_input("닉네임")

    # =========================
    # 날짜 선택
    # =========================

    st.subheader("가능한 날짜 선택")

    new_date = st.date_input(
        "날짜 선택"
    )

    col1, col2 = st.columns(2)

    with col1:

        if st.button("날짜 추가"):

            formatted_date = (
                new_date.strftime("%Y-%m-%d")
            )

            if (
                formatted_date
                not in st.session_state.selected_dates
            ):

                st.session_state.selected_dates.append(
                    formatted_date
                )

    with col2:

        if st.button("전체 삭제"):

            st.session_state.selected_dates = []

    st.write("선택된 날짜")

    for d in st.session_state.selected_dates:

        card_html = (
            f'<div style="'
            f'background:linear-gradient(135deg,#166534,#22c55e);'
            f'color:white;'
            f'padding:12px;'
            f'border-radius:14px;'
            f'margin:6px;'
            f'width:240px;'
            f'font-weight:bold;'
            f'box-shadow:0 4px 14px rgba(34,197,94,0.3);'
            f'">'
            f'📅 {d}'
            f'</div>'
        )

        st.markdown(
            card_html,
            unsafe_allow_html=True
        )

    # =========================
    # 위치 입력
    # =========================

    location_input = st.text_input(
        "위치 입력"
    )

    transport = st.selectbox(
        "이동수단",
        [
            "도보",
            "자전거",
            "대중교통",
            "자동차"
        ]
    )

    if st.button("정보 저장"):

        result = search_location(
            location_input
        )

        if result:

            save_user(
                room_id,
                nickname,
                ",".join(
                    st.session_state.selected_dates
                ),
                result["name"],
                result["lat"],
                result["lng"],
                transport
            )

            st.success("저장 완료")

        else:

            st.error(
                "위치를 찾을 수 없습니다"
            )

    # =========================
    # 참가자 목록
    # =========================

    st.subheader("현재 참가자")

    users_data = get_room_users(room_id)

    for user in users_data:

        participant_card = (
            f'<div style="'
            f'background:#1e293b;'
            f'padding:20px;'
            f'border-radius:18px;'
            f'margin-bottom:15px;'
            f'border-left:6px solid #22c55e;'
            f'box-shadow:0 4px 14px rgba(0,0,0,0.2);'
            f'">'
            f'<div style="font-size:24px;'
            f'font-weight:bold;'
            f'color:#22c55e;'
            f'margin-bottom:12px;">'
            f'👤 {user[2]}'
            f'</div>'
            f'<div style="margin-bottom:8px;">'
            f'📅 가능 날짜: {user[3]}'
            f'</div>'
            f'<div style="margin-bottom:8px;">'
            f'📍 위치: {user[4]}'
            f'</div>'
            f'<div>'
            f'🚗 이동수단: {user[7]}'
            f'</div>'
            f'</div>'
        )

        st.markdown(
            participant_card,
            unsafe_allow_html=True
        )

        
# =========================
# 추천 장소 계산
# =========================

users_data = []

if st.session_state.current_room:

    room_id = (
        st.session_state.current_room
    )

    users_data = get_room_users(
        room_id
    )

    st.write(
        f"현재 참가자 수: {len(users_data)}"
    )

    # =========================
    # 추천 버튼
    # =========================

    if len(users_data) >= 2:

        if st.button(
            "추천 장소 찾기",
            key="recommend_button"
        ):

            users = []

            for user in users_data:

                users.append({

                    "nickname": user[2],

                    "name": user[4],

                    "lat": user[5],

                    "lng": user[6],

                    "transport": user[7]
                })

            with st.spinner(
                "최적 장소 계산 중..."
            ):

                middle_lat, middle_lng = (
                    get_middle_point(users)
                )

                recommendations = (
                    recommend_places(
                        users,
                        middle_lat,
                        middle_lng
                    )
                )

                st.session_state.recommendations = (
                    recommendations
                )

                st.session_state.middle_lat = (
                    middle_lat
                )

                st.session_state.middle_lng = (
                    middle_lng
                )

    else:

        st.info(
            "추천 계산은 "
            "2명 이상 참가 시 가능합니다."
        )

# =========================
# 추천 결과 출력
# =========================

if (

    "recommendations"
    in st.session_state

    and

    st.session_state.recommendations

):

    recommendations = (
        st.session_state.recommendations
    )

    if len(recommendations) == 0:

        st.warning(
            "추천 장소를 찾을 수 없습니다."
        )

        st.stop()

    middle_lat = (
        st.session_state.middle_lat
    )

    middle_lng = (
        st.session_state.middle_lng
    )

    users = []

    for user in users_data:

        users.append({

            "nickname": user[2],

            "name": user[4],

            "lat": user[5],

            "lng": user[6],

            "transport": user[7]
        })

    best_place = recommendations[0]

    # =========================
    # 추천 장소 카드
    # =========================

    st.markdown(
        f"""
<div style="
background:#1e293b;
padding:24px;
border-radius:20px;
margin-bottom:20px;
border:2px solid #22c55e;
">

<div style="
font-size:32px;
font-weight:bold;
color:#22c55e;
margin-bottom:16px;
">
🌟 추천 장소
</div>

<div style="
font-size:28px;
margin-bottom:14px;
color:white;
">
{best_place["name"]}
</div>

<div style="
color:#d1fae5;
margin-bottom:8px;
">
⏱ 평균 이동시간:
{best_place["avg_time"]}분
</div>

<div style="
color:#d1fae5;
margin-bottom:8px;
">
🚦 최대 이동시간:
{best_place["max_time"]}분
</div>

<div style="
color:#d1fae5;
">
📍 {best_place["address"]}
</div>

</div>
""",
        unsafe_allow_html=True
    )

    # =========================
    # 사용자별 이동시간
    # =========================

    st.subheader(
        "사용자별 예상 이동시간"
    )

    for user in users:

        travel_time = get_route_time(

            user["lat"],
            user["lng"],

            best_place["lat"],
            best_place["lng"],

            user["transport"]
        )

        st.markdown(
            f"""
<div style="
background:#1e293b;
padding:18px;
border-radius:16px;
margin-bottom:12px;
border-left:5px solid #22c55e;
">

<div style="
font-size:22px;
font-weight:bold;
color:#22c55e;
margin-bottom:10px;
">
👤 {user["nickname"]}
</div>

<div style="
color:#d1fae5;
margin-bottom:6px;
">
🚗 이동수단:
{user["transport"]}
</div>

<div style="
color:#d1fae5;
">
⏱ 예상 이동시간:
{travel_time}분
</div>

</div>
""",
            unsafe_allow_html=True
        )

    # =========================
    # 지도
    # =========================

    st.divider()

    m = folium.Map(

        location=[
            middle_lat,
            middle_lng
        ],

        zoom_start=13,

        tiles="CartoDB dark_matter",

        control_scale=True,

        zoom_control=True,

        scrollWheelZoom=False
    )

    # 사용자 마커

    for user in users:

        folium.Marker(

            [user["lat"], user["lng"]],

            popup=user["nickname"],

            tooltip=user["nickname"],

            icon=folium.Icon(
                color="blue"
            )

        ).add_to(m)

    # 추천 장소 마커

    for idx, place in enumerate(
        recommendations[:5]
    ):

        color = (
            "red"
            if idx == 0
            else "green"
        )

        folium.Marker(

            [place["lat"], place["lng"]],

            popup=place["name"],

            tooltip=(
                f"{place['name']} "
                f"({place['avg_time']}분)"
            ),

            icon=folium.Icon(
                color=color
            )

        ).add_to(m)

    st_folium(

        m,

        use_container_width=True,

        height=700
    )