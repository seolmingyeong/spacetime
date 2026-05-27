import sqlite3


DB_NAME = "spacetime.db"


def get_connection():

    return sqlite3.connect(
        DB_NAME,
        check_same_thread=False
    )


def init_db():

    conn = get_connection()

    cursor = conn.cursor()

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

    conn.commit()

    conn.close()


# =========================
# database.py 수정
# save_user 함수 교체
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

    # 기존 사용자 삭제

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

    # 새로 저장

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
            lat,
            lng,
            place_id,
            transport
        )
    )

    conn.commit()

    conn.close()
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
# 방 존재 여부 확인
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

    count = cursor.fetchone()[0]

    conn.close()

    return count > 0