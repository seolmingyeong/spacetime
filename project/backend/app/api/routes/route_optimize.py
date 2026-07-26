import math

from fastapi import APIRouter

from app.models.schemas import RouteOptimizeRequest, RouteOptimizeResponse, LatLng

router = APIRouter()


def _haversine_km(a: LatLng, b: LatLng) -> float:
    """두 좌표 사이의 직선거리(km). 실제 도로 거리 API 연동 전까지의 근사치."""
    r = 6371.0
    lat1, lat2 = math.radians(a.lat), math.radians(b.lat)
    dlat = math.radians(b.lat - a.lat)
    dlng = math.radians(b.lng - a.lng)
    h = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    )
    return 2 * r * math.asin(math.sqrt(h))


@router.post("/optimize", response_model=RouteOptimizeResponse)
def optimize_route(req: RouteOptimizeRequest):
    """
    출발지(start)에서 시작해 모든 장소를 한 번씩 방문하는 최단 동선을
    Nearest-Neighbor 방식으로 근사 계산합니다.

    TODO(team):
    - 정확도가 중요해지면 2-opt 개선 또는 실제 도로 API(카카오모빌리티/구글 Directions)로 교체.
    - transport_mode(도보/대중교통/자동차)에 따른 실제 소요시간 반영.
    """
    remaining = list(req.places)
    current = req.start
    ordered: list[str] = []
    total_km = 0.0
    legs = []

    while remaining:
        nearest = min(remaining, key=lambda p: _haversine_km(current, p.location))
        dist = _haversine_km(current, nearest.location)
        total_km += dist
        legs.append({"to": nearest.id, "distance_km": round(dist, 2)})
        ordered.append(nearest.id)
        current = nearest.location
        remaining.remove(nearest)

    # 이동수단별 평균 속도(km/h)로 대략적인 소요시간 추정 (임시 값)
    avg_speed = {"car": 30, "walk": 4.5, "transit": 20}.get(req.transport_mode, 30)
    duration_min = (total_km / avg_speed) * 60 if avg_speed else 0.0

    return RouteOptimizeResponse(
        ordered_place_ids=ordered,
        total_distance_km=round(total_km, 2),
        total_duration_min=round(duration_min, 1),
        legs=legs,
    )
