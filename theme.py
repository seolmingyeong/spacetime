# =========================
# theme.py
# =========================

import streamlit as st


def apply_theme():

    st.markdown(
        '''
<style>

/* =========================
   자동 테마 대응
========================= */

:root {

    color-scheme:
        light dark;
}


/* =========================
   공통
========================= */

.block-container {

    max-width:1200px;

    padding-top:2rem;
}

svg {

    color:inherit !important;

    fill:inherit !important;
}

iframe {

    border-radius:24px;
}


/* =========================
   라이트 모드
========================= */

@media (prefers-color-scheme: light) {

    .stApp {

        background:
        linear-gradient(
            180deg,
            #fffdf7 0%,
            #f8fafc 40%,
            #eef2ff 100%
        );
    }

    html,
    body,
    p,
    span,
    label,
    div {

        color:#334155 !important;
    }

    .card {

        background:white;

        border:1px solid #e9d5ff;
    }

    .stTextInput input,
    .stSelectbox div[data-baseweb="select"] {

        background:white !important;

        color:#334155 !important;

        border:2px solid #ddd6fe !important;

        border-radius:16px;
    }
}


/* =========================
   다크 모드
========================= */

@media (prefers-color-scheme: dark) {

    .stApp {

        background:
        linear-gradient(
            180deg,
            #0f172a 0%,
            #111827 40%,
            #1e1b4b 100%
        );
    }

    html,
    body,
    p,
    span,
    label,
    div {

        color:#f8fafc !important;
    }

    .card {

        background:
        rgba(
            30,
            41,
            59,
            0.92
        );

        border:1px solid #312e81;
    }

    .stTextInput input,
    .stSelectbox div[data-baseweb="select"] {

        background:#1e293b !important;

        color:white !important;

        border:2px solid #4338ca !important;

        border-radius:16px;
    }

    .stSelectbox * {

        color:white !important;
    }
}


/* =========================
   버튼
========================= */

.stButton > button {

    width:100%;

    background:
    linear-gradient(
        90deg,
        #8b5cf6,
        #60a5fa
    ) !important;

    color:white !important;

    border:none;

    border-radius:18px;

    padding:14px;

    font-size:16px;

    font-weight:700;
}


/* =========================
   카드
========================= */

.card {

    border-radius:24px;

    padding:24px;

    margin-bottom:20px;

    transition:0.3s;
}

# =========================
# theme.py 추가 CSS
# 버튼 숨기기용
# =========================

button[kind="secondary"] {

    min-height:0px !important;

    height:0px !important;

    padding:0px !important;

    opacity:0;
}

</style>
''',
        unsafe_allow_html=True
    )

    