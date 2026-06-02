# =========================
# app.py
# =========================

import random
import string
import re
from datetime import date

import streamlit as st
import streamlit.components.v1 as components

from database import *
from recommendation import *
from route_api import *
from map_utils import *
from ui import *

from theme import apply_theme
from geo import geocode_location

from place_api import search_places

from streamlit_calendar import calendar

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

st.markdown("""
<style>

.fc {
    background: white;
    border-radius: 18px;
    padding: 12px;
    border: 1px solid #e5e7eb;
}

.fc-toolbar-title {
    color: #111827 !important;
    font-weight: 700 !important;
}

.fc-button {
    background: #8b5cf6 !important;
    border: none !important;
    border-radius: 10px !important;
}

.fc-daygrid-day-number {
    color: #374151 !important;
}

.fc-day-today {
    background: rgba(139,92,246,0.15) !important;
}

.fc-highlight {
    background: rgba(139,92,246,0.25) !important;
}
            
.fc-event {
    background: linear-gradient(
        90deg,
        #8b5cf6,
        #60a5fa
    ) !important;

    border: none !important;

    border-radius: 8px !important;

    min-height: 8px !important;
}

.fc-event-title {
    font-size: 11px !important;
    font-weight: 600 !important;
    text-align: center !important;
}

.fc-event {
    min-height: 18px !important;
}

.fc-daygrid-event-dot {
    display: none !important;
}

</style>
""", unsafe_allow_html=True)

# =========================
# DB 초기화
# =========================
init_db()

# =========================
# session state 초기화
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
    
# 자체 로그인 관련 세션
if "logged_in_user" not in st.session_state:
    st.session_state.logged_in_user = None

if "user_nickname" not in st.session_state:
    st.session_state.user_nickname = ""

# 방 안에서의 페이지(Step) 관리 세션 (1: 정보입력, 2: 캘린더 및 추천)
if "room_step" not in st.session_state:
    st.session_state.room_step = 1

if "show_category_select" not in st.session_state:
    st.session_state.show_category_select = False

if "meeting_category" not in st.session_state:
    st.session_state.meeting_category = None
# =========================
# ⏱️ 시간 형식 검증 유틸리티
# =========================
def validate_time_format(time_str):
    # HH:MM 형식 검증 (00:00 ~ 24:00 허용)
    return bool(re.match(r"^(0[0-9]|1[0-9]|2[0-4]):[0-5][0-9]$", time_str))


# =========================
# 🤝 공통 가능 시간 계산 알고리즘
# =========================
def calculate_overlap(users, target_date):
    total_participants = len(users)
    if total_participants == 0:
        return []
        
    participant_grids = []
    
    for user in users:
        dates_str = user[3]
        grid = [False] * 1441  # 24시간을 분 단위 그리드로 쪼갬 (0분부터 1440분까지)
        
        if not dates_str:
            participant_grids.append(grid)
            continue
            
        entries = dates_str.split(",")
        for entry in entries:
            entry = entry.strip()
            if not entry:
                continue
            parts = entry.split(" ", 1)
            date_part = parts[0]
            time_part = parts[1] if len(parts) > 1 else ""
            
            if date_part == target_date:
                if not time_part:
                    time_part = "00:00~24:00"
                
                if "~" in time_part:
                    t_start, t_end = time_part.split("~", 1)
                    try:
                        sh, sm = map(int, t_start.split(":"))
                        eh, em = map(int, t_end.split(":"))
                        start_min = sh * 60 + sm
                        end_min = eh * 60 + em
                        # 해당 시간대 분 활성화
                        for m in range(start_min, end_min):
                            if 0 <= m <= 1440:
                                grid[m] = True
                    except:
                        pass
        participant_grids.append(grid)
        
    # 모든 참가자의 비어있는 공통 교집합 시간 계산
    intersection_grid = [True] * 1441
    for grid in participant_grids:
        for m in range(1441):
            intersection_grid[m] = intersection_grid[m] and grid[m]
            
    # 분 단위 연속 구간을 다시 시간 인터벌(HH:MM)로 복원
    intervals = []
    in_interval = False
    start_min = 0
    
    for m in range(1441):
        if intersection_grid[m] and not in_interval:
            in_interval = True
            start_min = m
        elif not intersection_grid[m] and in_interval:
            in_interval = False
            end_min = m
            intervals.append((start_min, end_min))
    if in_interval:
        intervals.append((start_min, 1440))
        
    interval_strings = []
    for s, e in intervals:
        sh, sm = divmod(s, 60)
        eh, em = divmod(e, 60)
        interval_strings.append(f"{sh:02d}:{sm:02d} ~ {eh:02d}:{em:02d}")
        
    return interval_strings


# =========================
# 📋 원클릭 복사 클립보드 스크립트 콤포넌트 (iFrame 대응)
# =========================
def copy_to_clipboard_script(text_to_copy, button_label):
    html_code = f"""
    <div style="display: inline-block; width: 100%;">
        <button id="copyBtn" style="
            background: linear-gradient(135deg, #7c3aed, #4f46e5);
            color: white;
            border: none;
            padding: 10px 20px;
            font-size: 15px;
            font-weight: 700;
            border-radius: 12px;
            cursor: pointer;
            width: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            box-shadow: 0 4px 12px rgba(124, 58, 237, 0.25);
            transition: all 0.2s ease;
        " onmouseover="this.style.opacity='0.9'" onmouseout="this.style.opacity='1'">
            📋 {button_label}
        </button>
        <span id="toastMsg" style="
            display: none;
            position: fixed;
            bottom: 10px;
            left: 50%;
            transform: translateX(-50%);
            background-color: #333;
            color: #fff;
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 13px;
            z-index: 9999;
            box-shadow: 0 4px 10px rgba(0,0,0,0.3);
        ">방 코드가 복사되었습니다!</span>
        
        <textarea id="tempTextArea" style="position: absolute; left: -9999px;">{text_to_copy}</textarea>

        <script>
            document.getElementById('copyBtn').addEventListener('click', function() {{
                var copyTextarea = document.getElementById('tempTextArea');
                copyTextarea.focus();
                copyTextarea.select();
                try {{
                    var successful = document.execCommand('copy');
                    if (successful) {{
                        var toast = document.getElementById('toastMsg');
                        toast.style.display = 'block';
                        setTimeout(function() {{
                            toast.style.display = 'none';
                        }}, 2000);
                    }} else {{
                        alert('복사 실패');
                    }}
                }} catch (err) {{
                    alert('복사 중 예외 발생');
                }}
            }});
        </script>
    </div>
    """
    components.html(html_code, height=48)

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
# 1단계: 로그인 / 회원가입 화면
# =========================
if not st.session_state.logged_in_user:
    st.markdown(
        """
        <div style="text-align:center; margin-bottom: 20px;">
            <h3>스페이스타임에 로그인하여 시작하세요</h3>
        </div>
        """,
        unsafe_allow_html=True
    )
    
    login_tab, register_tab = st.tabs(["로그인", "회원가입"])
    
    with login_tab:
        col_l1, col_l2, col_l3 = st.columns([1, 2, 1])
        with col_l2:
            with st.container(border=True):
                login_id = st.text_input("아이디", key="login_id_input")
                login_pw = st.text_input("비밀번호", type="password", key="login_pw_input")
                
                st.markdown("<div style='height: 10px;'></div>", unsafe_allow_html=True)
                if st.button("로그인하기", key="login_btn", use_container_width=True):
                    if not login_id.strip() or not login_pw.strip():
                        st.error("아이디와 비밀번호를 모두 입력하세요.")
                    else:
                        user_nickname = login_account(login_id.strip(), login_pw.strip())
                        if user_nickname:
                            st.session_state.logged_in_user = login_id.strip()
                            st.session_state.user_nickname = user_nickname
                            st.session_state.nickname = user_nickname
                            st.success(f"{user_nickname}님, 환영합니다!")
                            st.rerun()
                        else:
                            st.error("아이디 또는 비밀번호가 올바르지 않습니다.")
            
    with register_tab:
        col_r1, col_r2, col_r3 = st.columns([1, 2, 1])
        with col_r2:
            with st.container(border=True):
                reg_id = st.text_input("새 아이디", key="reg_id_input")
                reg_pw = st.text_input("새 비밀번호", type="password", key="reg_pw_input")
                reg_nickname = st.text_input("사용할 이름/닉네임", key="reg_nick_input")
                
                st.markdown("<div style='height: 10px;'></div>", unsafe_allow_html=True)
                if st.button("회원가입하기", key="reg_btn", use_container_width=True):
                    if not reg_id.strip() or not reg_pw.strip() or not reg_nickname.strip():
                        st.error("모든 정보를 올바르게 입력해주세요.")
                    else:
                        success = register_account(reg_id.strip(), reg_pw.strip(), reg_nickname.strip())
                        if success:
                            st.success("회원가입에 성공했습니다! 로그인 탭에서 로그인을 진행해주세요.")
                        else:
                            st.error("이미 존재하는 아이디입니다.")

# =========================
# 로그인 성공 이후 화면
# =========================
else:
    top_col1, top_col2 = st.columns([8, 2])
    with top_col1:
        st.markdown(
            f"""
            <div style='padding: 10px 0;'>
                <b>{st.session_state.user_nickname}님</b>으로 로그인됨 ({st.session_state.logged_in_user})
            </div>
            """, 
            unsafe_allow_html=True
        )
    with top_col2:
        if st.button("로그아웃", key="logout_btn"):
            st.session_state.logged_in_user = None
            st.session_state.user_nickname = ""
            st.session_state.current_room = None
            st.session_state.recommendations = None
            st.session_state.room_step = 1
            st.rerun()

    st.markdown("<hr style='margin-top: 10px; margin-bottom: 30px;' />", unsafe_allow_html=True)

    # =========================
    # 2단계: 방 선택 및 생성 화면
    # =========================
    if not st.session_state.current_room:
        st.markdown("### 📅 내 약속 방 목록")
        my_rooms = get_user_rooms(st.session_state.logged_in_user)
        
        if my_rooms:
            cols_rooms = st.columns(3)
            for idx, r_id in enumerate(my_rooms):
                with cols_rooms[idx % 3]:
                    st.markdown(
                        f"""
                        <div class="card" style="margin-bottom:15px; border-left: 5px solid #8b5cf6;">
                            <h4 style="margin: 0 0 5px 0; color:#8b5cf6;">방 코드: {r_id}</h4>
                            <p style="font-size: 13px; opacity:0.7; margin:0;">내가 참여 중인 약속 공간</p>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )
                    if st.button(f"입장하기 ({r_id})", key=f"quick_join_{r_id}"):
                        st.session_state.current_room = r_id
                        st.session_state.recommendations = None
                        st.session_state.room_step = 1
                        st.rerun()
        else:
            st.info("아직 참여 중인 약속 방이 없습니다. 아래에서 새로 만들거나 입장하세요!")

        st.markdown("<div style='height: 30px;'></div>", unsafe_allow_html=True)

        col1, col2 = st.columns(2)

        with col1:
            st.markdown(
                """
                <div class="card">
                <h3>새 방 만들기</h3>
                <p>새로운 약속 공간 생성</p>
                </div>
                """, unsafe_allow_html=True
            )
            if st.button("방 만들기", key="create_room"):
                while True:
                    room_id = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
                    if not room_exists(room_id):
                        break
                join_room_db(st.session_state.logged_in_user, room_id)
                st.session_state.current_room = room_id
                st.session_state.room_step = 1
                st.rerun()

        with col2:
            st.markdown(
                """
                <div class="card">
                <h3>방 입장</h3>
                <p>기존 약속 공간 참여</p>
                </div>
                """, unsafe_allow_html=True
            )
            join_room = st.text_input("방 코드 입력")
            if st.button("입장하기", key="join_room"):
                join_room = join_room.strip()
                if not join_room:
                    st.error("방 코드를 입력하세요.")
                elif not room_exists(join_room):
                    st.error("존재하지 않는 방입니다.")
                else:
                    join_room_db(st.session_state.logged_in_user, join_room)
                    st.session_state.current_room = join_room
                    st.session_state.room_step = 1
                    st.rerun()

    # =========================
    # 방 입장 후 (상세 화면)
    # =========================
    else:
        col_back1, col_back2 = st.columns([8, 2])
        with col_back1:
            st.markdown(
                f"""
                <div class="card" style="margin-bottom:10px; text-align: center; padding: 25px;">
                    <p style="margin: 0 0 10px 0; font-weight: 500; font-size: 15px; opacity: 0.8;">현재 내가 입장 중인 모임 공간</p>
                    <h1 style="margin: 0; color: #8b5cf6; letter-spacing: 4px; font-size: 42px;">{st.session_state.current_room}</h1>
                </div>
                """,
                unsafe_allow_html=True
            )
            copy_to_clipboard_script(
                st.session_state.current_room, 
                "방 코드 복사하기"
            )
        with col_back2:
            st.markdown("<div style='height: 25px;'></div>", unsafe_allow_html=True)
            if st.button("목록으로 가기", key="back_to_list", use_container_width=True):
                st.session_state.current_room = None
                st.session_state.recommendations = None
                st.session_state.room_step = 1
                st.rerun()

        users_data = get_room_users(st.session_state.current_room)

        # ---------------------------------------------------------
        # STEP 1: 정보 입력 및 현재 멤버 현황
        # ---------------------------------------------------------
        if st.session_state.room_step == 1:
            st.markdown("<h3 style='margin-top:20px; margin-bottom:20px;'>내 정보 입력</h3>", unsafe_allow_html=True)
            
            col1, col2 = st.columns(2)
            with col1:
                nickname = st.text_input("닉네임", value=st.session_state.user_nickname if st.session_state.user_nickname else st.session_state.nickname)
                location_name = st.text_input("출발 위치")
            with col2:
                transport = st.selectbox("이동수단", ["대중교통", "자동차"])

            # 시간 직접 입력을 위한 UI 레이아웃
            from datetime import datetime, timedelta

            st.markdown(
                """
                <h3 style='margin-top:30px; margin-bottom:15px;'>
                📅 가능한 날짜 선택
                </h3>
                """,
                unsafe_allow_html=True
            )

            calendar_options = {
                "initialView": "dayGridMonth",
                "headerToolbar": {
                    "left": "prev,next",
                    "center": "title",
                    "right": ""
                },
                "height": 450
            }

            calendar_events = []

            # 이미 저장된 일정 표시
            for item in st.session_state.selected_dates:

                parts = item.split(" ", 1)

                date_only = parts[0]

                if len(parts) > 1:

                    time_text = parts[1]

                    if time_text == "00:00~24:00":
                        time_text = "상관없음"

                else:

                    time_text = "상관없음"

                calendar_events.append(
                    {
                        "title": time_text,
                        "start": date_only,
                        "backgroundColor": "#8b5cf6",
                        "borderColor": "#8b5cf6",
                        "textColor": "#ffffff"
                    }
                )

            # 아직 저장 안 된 선택 날짜 표시
            for date_only in st.session_state.calendar_selected_dates:

                already_saved = False

                for item in st.session_state.selected_dates:

                    if item.startswith(date_only):
                        already_saved = True
                        break

                if not already_saved:

                    calendar_events.append(
                        {
                            "title": "상관없음",
                            "start": date_only,
                            "backgroundColor": "#c4b5fd",
                            "borderColor": "#c4b5fd",
                            "textColor": "#ffffff"
                        }
                    )
            calendar_key = (
                "availability_calendar_"
                + str(hash(str(calendar_events)))
            )

            calendar_state = calendar(
                events=calendar_events,
                options=calendar_options,
                key=calendar_key
            )

            # 날짜 클릭 처리
            if (
                calendar_state
                and isinstance(calendar_state, dict)
                and calendar_state.get("callback") == "dateClick"
            ):

                clicked_date = (
                    datetime.fromisoformat(
                        calendar_state["dateClick"]["date"]
                        .replace("Z", "+00:00")
                    )
                    + timedelta(hours=9)
                ).strftime("%Y-%m-%d")

                existing_dates = [
                    item.split(" ")[0]
                    for item in st.session_state.selected_dates
                ]

                if clicked_date in existing_dates:

                    st.session_state.selected_dates = [
                        item
                        for item in st.session_state.selected_dates
                        if not item.startswith(clicked_date)
                    ]

                else:

                    st.session_state.selected_dates.append(
                        f"{clicked_date} 00:00~24:00"
                    )

                st.rerun()
             
            if st.session_state.selected_dates:

                st.markdown("### 선택된 일정")

                for idx, item in enumerate(
                    sorted(st.session_state.selected_dates)
                ):

                    parts = item.split(" ", 1)

                    date_only = parts[0]

                    current_time = (
                        parts[1]
                        if len(parts) > 1
                        else "00:00~24:00"
                    )

                    col1, col2, col3 = st.columns(
                        [4, 3, 1]
                    )

                    with col1:

                        st.markdown(
                            f"**{date_only}**"
                        )

                    with col2:

                        time_options = [
                            "상관없음",
                            "09:00~18:00",
                            "10:00~20:00",
                            "14:00~20:00",
                            "18:00~24:00"
                        ]

                        current_display = (
                            "상관없음"
                            if current_time == "00:00~24:00"
                            else current_time
                        )

                        selected_time = st.selectbox(
                            "시간",
                            time_options,
                            index=(
                                time_options.index(current_display)
                                if current_display in time_options
                                else 0
                            ),
                            key=f"time_{date_only}",
                            label_visibility="collapsed"
                        )

                        new_time = (
                            "00:00~24:00"
                            if selected_time == "상관없음"
                            else selected_time
                        )

                        st.session_state.selected_dates[idx] = (
                            f"{date_only} {new_time}"
                        )

                    with col3:

                        if st.button(
                            "삭제",
                            key=f"remove_{date_only}"
                        ):

                            st.session_state.selected_dates.remove(
                                item
                            )

                            st.rerun()

            if st.button("정보 저장", key=f"save_user_{st.session_state.current_room}"):
                if not nickname.strip():
                    st.error("닉네임을 입력하세요.")
                    st.stop()
                if not location_name.strip():
                    st.error("출발 위치를 입력하세요.")
                    st.stop()

                result = geocode_location(location_name.strip())
                if result is None:
                    st.error("출발 위치를 찾을 수 없습니다.")
                    st.stop()
                
                place_name, lat, lng = result
                if lat is None or lng is None:
                    st.error("좌표 변환 실패")
                    st.stop()

                save_user(
                    st.session_state.current_room,
                    nickname,
                    ",".join(st.session_state.selected_dates),
                    place_name,
                    lat,
                    lng,
                    None,
                    transport
                )
                st.success("정보 저장 완료!")
                st.rerun()

            if len(users_data) > 0:
                st.markdown("<h2 style='margin-top:40px; margin-bottom:20px;'>현재 참가자 현황</h2>", unsafe_allow_html=True)
                grid_cols = st.columns(4)
                for idx, user in enumerate(users_data):
                    with grid_cols[idx % 4]:
                        st.markdown(f"""
                        <div class="card" style="text-align: center; padding: 18px 10px; border-top: 4px solid #8b5cf6;">
                            <div style="font-size:20px; font-weight:700; color:#8b5cf6;">{user[2]}</div>
                        </div>
                        """, unsafe_allow_html=True)

            if len(users_data) >= 2:
                st.markdown("<hr style='margin-top: 40px; margin-bottom: 20px;' />", unsafe_allow_html=True)
                st.info("💡 멤버들이 모두 정보를 입력했다면 아래 버튼을 눌러 다음 단계로 이동하세요!")
                
                col_btn1, col_btn2, col_btn3 = st.columns([1,2,1])
                with col_btn2:
                    if st.button(f"📅 가능 날짜/시간 모아보기 ({len(users_data)}명 참여중)", use_container_width=True):
                        st.session_state.room_step = 2
                        st.session_state.recommendations = None
                        st.rerun()


        # ---------------------------------------------------------
        # STEP 2: 캘린더 화면 및 추천 장소 도출
        # ---------------------------------------------------------
        elif st.session_state.room_step == 2:
            st.markdown("<h2 style='margin-top:10px; margin-bottom:20px;'>📅 날짜 및 시간 조율 캘린더</h2>", unsafe_allow_html=True)
            
            # 날짜 및 시간 취합/파싱 로직
            date_user_times = {} # 구조: { '2026-06-18': { '유저이름': ['10:30~16:00', '18:00~20:00'] } }
            total_members = len(users_data)

            for user in users_data:
                dates_str = user[3]
                if not dates_str: continue
                entries = dates_str.split(",")
                name = user[2]

                for entry in entries:
                    entry = entry.strip()
                    if not entry: continue

                    # 띄어쓰기로 날짜와 시간 분리
                    parts = entry.split(" ", 1)
                    date_part = parts[0]
                    time_part = parts[1] if len(parts) > 1 else ""

                    if date_part not in date_user_times:
                        date_user_times[date_part] = {}
                    if name not in date_user_times[date_part]:
                        date_user_times[date_part][name] = []

                    if time_part:
                        display_time = time_part.replace("00:00~24:00", "상관없음")
                        date_user_times[date_part][name].append(display_time)

            if not date_user_times:
                st.warning("등록된 가능 일정이 없습니다. 이전 단계로 돌아가 일정을 추가해주세요.")
                if st.button("⬅️ 이전 단계로 돌아가기"):
                    st.session_state.room_step = 1
                    st.rerun()
            else:
                sorted_dates = sorted(date_user_times.keys())
                
                st.markdown("<p style='font-size: 16px; opacity: 0.8;'>멤버들이 등록한 일정입니다. 색상이 진할수록 모두가 가능한 날짜입니다.</p>", unsafe_allow_html=True)
                
                cal_cols = st.columns(4)
                for i, date_str in enumerate(sorted_dates):
                    users_on_date = date_user_times[date_str]
                    count = len(users_on_date)
                    is_perfect = (count == total_members)
                    
                    bg_style = "background: linear-gradient(90deg, #8b5cf6, #60a5fa); color: white;" if is_perfect else "background: #f3f4f6; color: #374151; border: 1px solid #e5e7eb;"
                    border_style = "border: 2px solid #8b5cf6;" if is_perfect else ""
                    
                    # 캘린더 내부에 표시할 "이름 (시간)" 텍스트 구성
                    user_time_displays = []
                    for uname, utimes in users_on_date.items():
                        if utimes:
                            time_str = ", ".join(utimes)
                            user_time_displays.append(f"<span style='font-weight:600;'>{uname}</span> <span style='opacity:0.85;'>({time_str})</span>")
                        else:
                            user_time_displays.append(f"<span style='font-weight:600;'>{uname}</span>")

                    details_html = "<br>".join(user_time_displays)
                    
                    with cal_cols[i % 4]:
                        st.markdown(f"""
                        <div style="padding: 15px; border-radius: 12px; margin-bottom: 15px; text-align: center; {bg_style} {border_style}">
                            <h3 style="margin: 0; font-size: 20px;">{date_str}</h3>
                            <p style="margin: 5px 0 10px 0; font-size: 14px;"><strong>{count}/{total_members}</strong> 명 가능</p>
                            <div style="font-size: 12px; line-height: 1.6; padding-top: 8px; border-top: 1px solid rgba(128,128,128,0.2);">
                                {details_html}
                            </div>
                        </div>
                        """, unsafe_allow_html=True)

                st.markdown("<hr style='margin-top: 30px; margin-bottom: 30px;' />", unsafe_allow_html=True)

                st.markdown("### 🎯 최종 약속 날짜 선택")
                final_date = st.selectbox("위 캘린더를 참고하여 모임 날짜를 하나 선택해주세요.", sorted_dates)

                if final_date:
                    # 피드백 반영: 선택된 날짜에 모든 참가자가 동시에 가능한 '겹치는 시간'을 자동으로 계산하여 출력
                    overlap_slots = calculate_overlap(users_data, final_date)
                    
                    if overlap_slots:
                        # 겹치는 공통 시간이 존재하는 경우
                        clean_slots = [slot.replace("00:00 ~ 24:00", "하루 종일 (상관없음)") for slot in overlap_slots]
                        st.markdown(f"""
                        <div style="background: #f3e8ff; border-left: 5px solid #8b5cf6; padding: 18px; border-radius: 12px; margin-top: 15px; margin-bottom: 25px;">
                            <h4 style="margin: 0 0 8px 0; color: #7c3aed; font-size: 17px; font-weight: 700;">👥 멤버 모두가 가능한 골든 타임 (공통 시간)</h4>
                            <p style="margin: 0; font-size: 21px; font-weight: 800; color: #1e1b4b; letter-spacing: -0.5px;">
                                {" / ".join(clean_slots)}
                            </p>
                            <p style="margin: 6px 0 0 0; font-size: 12px; opacity: 0.75; color: #1e1b4b;">
                                * 위 겹치는 공통 시간대 중에 만나시면 모두가 지체 없이 한 번에 모일 수 있습니다!
                            </p>
                        </div>
                        """, unsafe_allow_html=True)
                    else:
                        # 공통 교집합 시간이 없을 때
                        st.markdown(f"""
                        <div style="background: #fef2f2; border-left: 5px solid #ef4444; padding: 18px; border-radius: 12px; margin-top: 15px; margin-bottom: 25px;">
                            <h4 style="margin: 0 0 6px 0; color: #b91c1c; font-size: 16px; font-weight: 700;">⚠️ 모두가 가능한 공통 시간이 없습니다!</h4>
                            <p style="margin: 0; font-size: 13px; color: #7f1d1d; line-height: 1.5;">
                                멤버들의 가능 시간 정보가 겹치지 않고 서로 어긋나 있습니다. <br>
                                위 캘린더에 기재된 개별 멤버들의 시간 정보를 참고하셔서, 서로 타협 가능한 시간대를 구두나 메신저로 조금씩 양보하여 결정해 주세요.
                            </p>
                        </div>
                        """, unsafe_allow_html=True)

                col_actions1, col_actions2 = st.columns([1, 1])
                with col_actions1:
                    if st.button("⬅️ 다시 정보 수정하기"):
                        st.session_state.room_step = 1
                        st.session_state.recommendations = None
                        st.rerun()
                
                with col_actions2:
                    if final_date:
                        if st.button(
                            "🔍 이 날짜로 추천 장소 찾기",
                            type="primary",
                            use_container_width=True
                        ):
                            st.session_state.show_category_select = True
                            st.rerun()

                if st.session_state.show_category_select:

                    st.markdown("---")

                    st.markdown(
                        """
                        <h3 style='text-align:center; margin-bottom:20px;'>
                        어디서 만나고 싶으신가요?
                        </h3>
                        """,
                        unsafe_allow_html=True
                    )

                    category_cols = st.columns(5)

                    categories = [
                        ("☕ 카페", "카페"),
                        ("🍽 음식점", "맛집"),
                        ("🎬 영화관", "영화관"),
                        ("🌳 공원", "공원"),
                        ("✨ 상관없음", "상관없음")
                    ]

                    for idx, (label, category) in enumerate(categories):

                        with category_cols[idx]:

                            if st.button(
                                label,
                                key=f"category_{category}",
                                use_container_width=True
                            ):

                                st.session_state.meeting_category = category

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

                                with st.spinner(
                                    f"{category} 추천 장소를 찾는 중..."
                                ):

                                    recommendations = recommend_places(
                                        users,
                                        category
                                    )

                                    st.session_state.recommendations = recommendations

                                st.rerun()

            # =========================
            # 하단: 추천 결과 및 지도
            # =========================
            if st.session_state.recommendations is not None:
                st.markdown("<hr style='border: 2px dashed #8b5cf6; margin: 40px 0;' />", unsafe_allow_html=True)

                if len(st.session_state.recommendations) > 0:
                    recommendations = st.session_state.recommendations
                    
                    st.markdown(
                        """
                        <h2 style="margin-bottom:20px;">📍 추천 장소 결과</h2>
                        """,
                        unsafe_allow_html=True
                    )

                    for idx, place in enumerate(recommendations):
                        st.markdown(
                            f"""
                            <h3 style="margin-top:25px; margin-bottom:10px; color:#8b5cf6;">
                            #{idx + 1} 추천
                            </h3>
                            """,
                            unsafe_allow_html=True
                        )
                        render_place_card(place)

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

                    st.markdown("<h2 style='margin-top:40px; margin-bottom:20px;'>🗺️ 이동 경로 지도</h2>", unsafe_allow_html=True)
                    render_map(users, recommendations)
                else:
                    st.warning("⚠️ 추천할 수 있는 카페를 찾지 못했습니다. Google/Kakao API 호출 제한에 도달했거나, 출발 지점들의 거리가 너무 멀지 않은지 세팅 상태를 다시 한 번 확인해 주세요.")