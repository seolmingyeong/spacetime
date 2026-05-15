import math


def get_middle_point(users):

    avg_lat = sum(
        user["lat"]
        for user in users
    ) / len(users)

    avg_lng = sum(
        user["lng"]
        for user in users
    ) / len(users)

    return avg_lat, avg_lng


def recommend_places(
    users,
    middle_lat,
    middle_lng
):

    return [

        {
            "name": "스타벅스 강남점",
            "lat": middle_lat,
            "lng": middle_lng,
            "address": "서울 강남구",
            "avg_time": 25,
            "max_time": 40
        }

    ]