# 여행 그룹 플래닝 앱 - 스켈레톤

플로우차트(로그인 → 홈 → 내 일정 / 방 목록 / 기록 / 프로필, AI 장소·코스·중간지점 추천)를
기반으로 한 초기 프로젝트 구조입니다. UI와 API는 뼈대만 구현되어 있고, 실제 로직은
`TODO(team)` 주석이 달린 부분에서 팀원들과 채워나가면 됩니다.

## 구조

```
project/
├── flutter_app/        # Flutter 프론트엔드 (iOS/Android)
│   └── lib/
│       ├── main.dart
│       ├── core/        # 테마, Supabase 클라이언트 설정
│       ├── widgets/      # 공통 위젯 (하단 네비게이션 등)
│       ├── models/       # 데이터 모델 (Room, Schedule, Record...)
│       └── features/     # 화면 단위 (auth, home, room, schedule, profile)
├── backend/             # FastAPI (AI 추천 / 경로 계산 전용 서버)
│   └── app/
│       ├── main.py
│       ├── api/routes/   # recommend, route_optimize, midpoint
│       ├── core/         # 환경설정
│       └── models/       # pydantic 스키마
└── supabase/
    └── schema.sql        # DB 테이블 초안 (rooms, schedules, places, records...)
```

## 역할 분담 제안

- **Flutter**: 화면 UI, 상태관리, Supabase Auth/DB 클라이언트 호출
- **FastAPI**: 장소 추천 알고리즘, 최적 경로(TSP) 계산, 중간지점 추천 — "계산이 필요한" 기능만 담당
- **Supabase**: 회원가입/로그인, 방/일정/기록 등 단순 CRUD는 Flutter에서 Supabase SDK로 직접 처리 (FastAPI를 거치지 않아도 됨)

## 실행 방법

### 1. Flutter
```bash
cd flutter_app
flutter pub get
flutter run
```
`lib/core/supabase_client.dart` 에 실제 Supabase URL/anon key를 넣고
`main.dart` 의 `SupabaseConfig.init()` 주석을 해제하세요.

### 2. FastAPI
```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
`http://localhost:8000/docs` 에서 Swagger로 API 테스트 가능합니다.

### 3. Supabase
1. https://supabase.com 에서 새 프로젝트 생성
2. SQL Editor에서 `supabase/schema.sql` 실행
3. Project Settings > API 에서 URL / anon key 확인 후 Flutter에 연결

## 다음 단계 (팀원과 함께)

1. Supabase 프로젝트 생성 및 실제 URL/Key 연결, 이메일/소셜 로그인 활성화
2. 방 목록/생성/입장을 목업 데이터 → 실제 Supabase 쿼리로 교체
3. 일정 생성/투표/확정 로직 구현 (schedules, schedule_votes 테이블 활용)
4. FastAPI 장소 추천에 실제 장소 데이터 소스(지도 API) 연결
5. 최적 경로 계산을 Haversine 근사 → 실제 도로 API 기반으로 고도화
6. 기록(사진 업로드) 기능에 Supabase Storage 연결
7. RLS 정책을 방 멤버 기준으로 세밀하게 설정 (현재는 기본 뼈대만 존재)
