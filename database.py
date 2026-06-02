import sqlite3
import hashlib

DB_NAME = "spacetime.db"


# =========================
# DB 연결
# =========================

def get_connection():
    return sqlite3.connect(
        DB_NAME,
        check_same_thread=False
    )


# =========================
# DB 초기화
# =========================

def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    # 기존 users 테이블 (방 안에서의 참가자 출발 정보 저장)
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS users (

            id INTEGER PRIMARY KEY AUTOINCREMENT,

            room_id TEXT,

            nickname TEXT,

            dates TEXT,

            location_name TEXT,

            lat REAL,

            lng REAL,

            place_id TEXT,

            transport TEXT
        )
        """
    )

    # 1. 자체 계정 관리 테이블 (accounts)
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS accounts (
            username TEXT PRIMARY KEY,
            password TEXT,
            nickname TEXT
        )
        """
    )

    # 2. 방 멤버십/가입 목록 테이블 (room_participants)
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS room_participants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            room_id TEXT,
            joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(username, room_id)
        )
        """
    )

    conn.commit()
    conn.close()


# =========================
# 회원가입 및 로그인 비즈니스 로직
# =========================

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()


def register_account(username, password, nickname):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        hashed = hash_password(password)
        cursor.execute(
            """
            INSERT INTO accounts (username, password, nickname)
            VALUES (?, ?, ?)
            """,
            (username, hashed, nickname)
        )
        conn.commit()
        success = True
    except sqlite3.IntegrityError:
        success = False  # 중복 아이디
    finally:
        conn.close()
    return success


def login_account(username, password):
    conn = get_connection()
    cursor = conn.cursor()
    hashed = hash_password(password)
    cursor.execute(
        """
        SELECT nickname FROM accounts
        WHERE username=? AND password=?
        """,
        (username, hashed)
    )
    result = cursor.fetchone()
    conn.close()
    if result:
        return result[0]  # nickname 반환
    return None


# =========================
# 유저별 참여 중인 방 목록 관리
# =========================

def join_room_db(username, room_id):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            INSERT OR IGNORE INTO room_participants (username, room_id)
            VALUES (?, ?)
            """,
            (username, room_id)
        )
        conn.commit()
    finally:
        conn.close()


def get_user_rooms(username):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT room_id FROM room_participants
        WHERE username=?
        ORDER BY joined_at DESC
        """,
        (username,)
    )
    rows = cursor.fetchall()
    conn.close()
    return [row[0] for row in rows]


# =========================
# 기존 사용자 저장 (방 상세용)
# =========================

def save_user(
    room_id,
    nickname,
    dates,
    location_name,
    lat,
    lng,
    place_id,
    transport
):

    conn = get_connection()

    cursor = conn.cursor()

    # =========================
    # 값 검증
    # =========================

    if lat is None:

        raise ValueError(
            "lat is None"
        )

    if lng is None:

        raise ValueError(
            "lng is None"
        )

    # =========================
    # 기존 사용자 삭제
    # =========================

    cursor.execute(
        """
        DELETE FROM users
        WHERE room_id=?
        AND nickname=?
        """,
        (
            room_id,
            nickname
        )
    )

    # =========================
    # 새 사용자 저장
    # =========================

    cursor.execute(
        """
        INSERT INTO users (

            room_id,

            nickname,

            dates,

            location_name,

            lat,

            lng,

            place_id,

            transport
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            room_id,
            nickname,
            dates,
            location_name,
            float(lat),
            float(lng),
            place_id,
            transport
        )
    )

    conn.commit()
    conn.close()


# =========================
# 방 참가자 조회
# =========================

def get_room_users(room_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT *
        FROM users
        WHERE room_id=?
        """,
        (room_id,)
    )

    users = cursor.fetchall()

    conn.close()

    return users


# =========================
# 방 존재 여부
# =========================

def room_exists(room_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT COUNT(*)
        FROM users
        WHERE room_id=?
        """,
        (room_id,)
    )

    count_users = cursor.fetchone()[0]
    
    # 방 참여자 맵핑 테이블에라도 존재하는지 교차 검증
    cursor.execute(
        """
        SELECT COUNT(*)
        FROM room_participants
        WHERE room_id=?
        """,
        (room_id,)
    )
    count_participants = cursor.fetchone()[0]
    conn.close()
    return (count_users > 0) or (count_participants > 0)


# =========================
# 전체 사용자 삭제
# =========================
def clear_all_users():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        DELETE FROM users
        """
    )

    conn.commit()
    conn.close()