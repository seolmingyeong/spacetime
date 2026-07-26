from pydantic import BaseModel


class LatLng(BaseModel):
    lat: float
    lng: float


class Place(BaseModel):
    id: str
    name: str
    category: str | None = None
    location: LatLng
    rating: float | None = None
    price_level: int | None = None  # 1(저렴) ~ 4(고가)


# ---------- 장소/코스 추천 ----------
class PlaceRecommendRequest(BaseModel):
    room_id: str
    center: LatLng  # 기준 위치 (예: 숙소, 이전 방문지)
    preferences: list[str] = []  # 예: ["카페", "자연", "액티비티"]
    radius_km: float = 5.0
    sort_by: str = "distance"  # "distance" | "popularity" | "price"


class CourseRecommendRequest(BaseModel):
    room_id: str
    place_ids: list[str]
    start: LatLng
    transport_mode: str = "car"  # "car" | "walk" | "transit"


class CourseRecommendResponse(BaseModel):
    ordered_place_ids: list[str]
    total_distance_km: float
    total_duration_min: float


# ---------- 최적 경로 계산 ----------
class RouteOptimizeRequest(BaseModel):
    places: list[Place]
    start: LatLng
    transport_mode: str = "car"


class RouteOptimizeResponse(BaseModel):
    ordered_place_ids: list[str]
    total_distance_km: float
    total_duration_min: float
    legs: list[dict]  # 구간별 상세 정보 (거리/시간)


# ---------- 중간지점(만날 장소) 추천 ----------
class MidpointRequest(BaseModel):
    member_locations: list[LatLng]  # 각 멤버의 현재/출발 위치
    category: str | None = None  # 예: "카페", "지하철역"


class MidpointCandidate(BaseModel):
    place: Place
    max_travel_time_min: float  # 참여자 중 가장 오래 걸리는 사람의 소요 시간
    fairness_score: float  # 참여자 간 이동시간 편차가 적을수록 높은 점수


class MidpointResponse(BaseModel):
    midpoint: LatLng
    candidates: list[MidpointCandidate]
