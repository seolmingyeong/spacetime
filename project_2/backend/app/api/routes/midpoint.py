from fastapi import APIRouter

from app.models.schemas import MidpointRequest, MidpointResponse, LatLng

router = APIRouter()


@router.post("", response_model=MidpointResponse)
def recommend_midpoint(req: MidpointRequest):
    """
    참여자들의 위치(member_locations)를 기반으로 만나기 좋은 중간지점을 추천합니다.

    현재는 단순 평균 좌표(geometric centroid)를 중간지점으로 계산합니다.
    TODO(team):
    - 실제로는 '예상 소요시간' 기반 중간지점(예: 각자 이동시간이 최소/균등한 지점)으로 고도화.
    - 지도 API로 중간지점 주변의 카페/지하철역 등 실제 장소(candidates)를 채워서 반환.
    """
    n = len(req.member_locations)
    if n == 0:
        return MidpointResponse(midpoint=LatLng(lat=0, lng=0), candidates=[])

    avg_lat = sum(p.lat for p in req.member_locations) / n
    avg_lng = sum(p.lng for p in req.member_locations) / n

    return MidpointResponse(
        midpoint=LatLng(lat=avg_lat, lng=avg_lng),
        candidates=[],  # TODO(team): 주변 실제 장소 후보 채우기
    )
