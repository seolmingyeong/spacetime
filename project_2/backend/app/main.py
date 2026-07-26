from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import recommend, route_optimize, midpoint
from app.core.config import settings

app = FastAPI(
    title="Travel Together API",
    description="장소 추천 / 최적 경로 계산 / 중간지점 추천을 담당하는 AI 알고리즘 서버. "
                 "회원가입/인증/기본 CRUD는 Supabase가 직접 처리하고, "
                 "이 서버는 계산이 필요한 기능만 담당합니다.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(recommend.router, prefix="/api/recommend", tags=["장소/코스 추천"])
app.include_router(route_optimize.router, prefix="/api/route", tags=["최적 경로"])
app.include_router(midpoint.router, prefix="/api/midpoint", tags=["중간지점 추천"])


@app.get("/health")
def health_check():
    return {"status": "ok"}
