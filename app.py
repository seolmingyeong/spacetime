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

                    "location_name": user[4],

                    "lat": user[5],

                    "lng": user[6],

                    "transport": user[7]
                })

            # =========================
            # 디버그 출력
            # =========================

            st.session_state.debug_users = (
                users
            )

            # =========================
            # 중간 좌표 계산
            # =========================

            middle_lat, middle_lng = (
                get_middle_point(users)
            )

            # =========================
            # 추천 장소 계산
            # =========================

            recommendations = (
                recommend_places(

                    users,

                    middle_lat,

                    middle_lng
                )
            )

            # =========================
            # session 저장
            # =========================

            st.session_state.recommendations = (
                recommendations
            )

            st.session_state.middle_lat = (
                middle_lat
            )

            st.session_state.middle_lng = (
                middle_lng
            )


# =========================
# 디버그 정보 출력
# =========================

if "debug_users" in st.session_state:

    st.markdown(
        """
<h3 style="
margin-top:30px;
color:red;
">
DEBUG USERS
</h3>
""",
        unsafe_allow_html=True
    )

    st.write(
        st.session_state.debug_users
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

            "location_name": user[4],

            "lat": user[5],

            "lng": user[6],

            "transport": user[7]
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

        recommendations,

        st.session_state.middle_lat,

        st.session_state.middle_lng
    )