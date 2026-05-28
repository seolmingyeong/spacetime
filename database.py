import sqlite3


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
# 사용자 저장
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
    # DEBUG
    # =========================

    print("SAVE USER")

    print({

        "room_id":
        room_id,

        "nickname":
        nickname,

        "dates":
        dates,

        "location_name":
        location_name,

        "lat":
        lat,

        "lng":
        lng,

        "place_id":
        place_id,

        "transport":
        transport
    })

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

    print(
        "SAVE SUCCESS"
    )


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

    # =========================
    # DEBUG
    # =========================

    print("ROOM USERS")

    for user in users:

        print(user)

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

    count = cursor.fetchone()[0]

    conn.close()

    return count > 0


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

    print(
        "ALL USERS DELETED"
    )