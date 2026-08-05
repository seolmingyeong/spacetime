# FastAPI 백엔드 및 API 전달 안내

백엔드 소스는 `project_seol/backend`에 모두 포함되어 있습니다.

## 포함된 API

- `GET /health`: 서버 상태 확인
- `/api/recommend`: 장소 및 코스 추천 뼈대
- `/api/route`: 선택 장소의 경로 최적화 뼈대
- `/api/midpoint`: 멤버 위치의 중간 지점 계산 뼈대

라우트 소스 파일은 다음 위치에 있습니다.

```text
project_seol/backend/app/api/routes/recommend.py
project_seol/backend/app/api/routes/route_optimize.py
project_seol/backend/app/api/routes/midpoint.py
```

## 환경변수 준비

`backend/.env.example`을 복사하여 `backend/.env`를 만들고 각 팀원이 자신의 개발 환경 값을 입력합니다.

```powershell
cd project_seol\backend
Copy-Item .env.example .env
```

`SUPABASE_SERVICE_KEY`는 관리자 권한을 가진 비밀 키이므로 Flutter 코드, Git 저장소 또는 팀 공용 문서에 직접 넣으면 안 됩니다. 실제 키는 팀에서 승인된 비밀 공유 수단으로만 전달하세요. Flutter에는 공개용 publishable/anon key만 사용합니다.

## 실행

```powershell
cd project_seol\backend
py -3.12 -m venv venv
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Swagger 문서:

```text
http://127.0.0.1:8000/docs
```

Android 에뮬레이터에서 PC 백엔드를 호출할 때 사용할 기본 주소:

```text
http://10.0.2.2:8000
```

현재 방·친구·일정·기록 CRUD는 Flutter가 Supabase에 직접 연결하고, FastAPI는 추천·경로·중간지점처럼 계산이 필요한 기능을 담당하도록 분리되어 있습니다. 따라서 API 소스는 보존되어 있지만, 각 Flutter 화면에서 실제 추천 버튼을 누를 때 FastAPI를 호출하도록 연결하는 작업은 외부 지도 API를 결정한 뒤 이어서 구현해야 합니다.
