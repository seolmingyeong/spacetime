from fastapi import APIRouter

from app.models.schemas import (
    PlaceRecommendRequest,
    Place,
    CourseRecommendRequest,
    CourseRecommendResponse,
)

router = APIRouter()


@router.post("/places", response_model=list[Place])
def recommend_places(req: PlaceRecommendRequest):
    """
    사용자 취향(preferences) / 거리(radius_km) / 인기도 등을 기반으로
    장소를 추천합니다.

    TODO(team):
    - 실제로는 place DB(예: 카카오맵/구글맵 Places API 또는 자체 수집 DB)에서
      반경 내 장소를 조회한 뒤, sort_by 기준(distance/popularity/price)으로 정렬.
    - 추후 사용자별 좋아요/기록 데이터를 반영한 개인화 추천으로 확장 가능.
    """
    # 임시 더미 응답 (알고리즘 붙이기 전 UI 확인용)
    return [
        Place(
            id="dummy-1",
            name="예시 카페",
            category="카페",
            location=req.center,
            rating=4.5,
            price_level=2,
        )
    ]


@router.post("/course", response_model=CourseRecommendResponse)
def recommend_course(req: CourseRecommendRequest):
    """
    선택된 장소들(place_ids)을 이동 효율이 가장 좋은 순서로 재배열합니다.
    내부적으로 route_optimize 로직(TSP 근사 알고리즘)을 재사용할 예정입니다.

    TODO(team): app.api.routes.route_optimize 의 최적화 함수를 호출하도록 연결.
    """
    return CourseRecommendResponse(
        ordered_place_ids=req.place_ids,
        total_distance_km=0.0,
        total_duration_min=0.0,
    )
