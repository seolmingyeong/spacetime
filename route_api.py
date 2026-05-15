def get_route_time(
    start_lat,
    start_lng,
    end_lat,
    end_lng,
    transport
):

    if transport == "도보":

        return 35

    elif transport == "대중교통":

        return 28

    elif transport == "자동차":

        return 18

    return 30