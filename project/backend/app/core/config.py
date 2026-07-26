from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # TODO(team): 실제 배포 시 .env 파일로 분리하고 여기서는 os.environ 으로만 읽기
    SUPABASE_URL: str = "https://YOUR_PROJECT_ID.supabase.co"
    SUPABASE_SERVICE_KEY: str = "YOUR_SUPABASE_SERVICE_ROLE_KEY"

    # 지도/경로 계산에 사용할 외부 API 키 (예: 카카오맵, 네이버지도, Google Maps 등)
    MAP_API_KEY: str = "YOUR_MAP_API_KEY"

    ALLOWED_ORIGINS: list[str] = ["*"]  # TODO(team): 배포 시 앱 도메인으로 제한

    class Config:
        env_file = ".env"


settings = Settings()
