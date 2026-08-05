# 여행메이트 수정본 적용 및 실행 안내

이 압축파일은 기존 프로젝트의 기능을 확장한 전체 소스입니다. 기존 폴더를 먼저 복사해 백업한 뒤 적용하세요.

## 1. Supabase 데이터베이스 업데이트

기존 `supabase Query 1~4`를 이미 실행해 테이블이 만들어져 있다면 다시 실행하지 마세요.

1. Supabase Dashboard에서 해당 프로젝트를 엽니다.
2. **SQL Editor → New query**를 누릅니다.
3. `project_seol/supabase/20260806_full_feature_migration.sql`의 내용을 전부 붙여넣습니다.
4. **Run**을 한 번만 누릅니다.
5. Table Editor에서 `room_invitations`, `friend_requests`, `friendships`, `personal_schedules`, `record_albums`, `record_entries`, `record_photos`, `notifications` 등이 생겼는지 확인합니다.
6. Storage에서 `avatars`, `record-media` 버킷이 생겼는지 확인합니다.

## 2. Google 로그인 설정

Supabase에서 다음을 확인하세요.

1. **Authentication → Providers → Google**을 활성화하고 Google Cloud의 Client ID와 Client Secret을 입력합니다.
2. Google Cloud Console의 OAuth 승인된 리디렉션 URI에는 Supabase가 화면에 보여주는 callback URL을 등록합니다. 보통 `https://<프로젝트-ref>.supabase.co/auth/v1/callback` 형태입니다.
3. Supabase **Authentication → URL Configuration → Redirect URLs**에 아래 주소를 추가합니다.

```text
io.supabase.traveltogether://login-callback/
```

Google Cloud의 Client ID/Secret은 Google 로그인을 위해 필요하지만, Google Drive 사진 업로드용 권한은 필요하지 않습니다. 사진은 휴대폰 갤러리/카메라에서 골라 Supabase Storage에 저장됩니다.

## 3. Flutter 실행

PowerShell 새 창에서 다음 명령을 순서대로 실행하세요.

```powershell
cd C:\Users\jae\Documents\Project\IT_seol\project_seol\flutter_app
Remove-Item .\pubspec.lock -ErrorAction SilentlyContinue
flutter pub get
flutter run -d emulator-5554
```

`pubspec.lock` 삭제는 패키지 버전을 새 설정에 맞춰 다시 계산하기 위한 것이며, `flutter pub get`이 즉시 새 파일을 만듭니다.

앱에서 Google 로그인을 누른 뒤 브라우저 인증을 마치면 앱으로 돌아와야 합니다. 첫 로그인에서는 닉네임과 앱 아이디를 입력하는 추가 정보 화면이 나타납니다.

## 4. 백엔드 실행

현재 추가된 방·친구·일정·기록 CRUD는 Flutter에서 Supabase를 직접 사용합니다. AI 추천 API를 시험할 때만 FastAPI가 필요합니다.

```powershell
cd C:\Users\jae\Documents\Project\IT_seol\project_seol\backend
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Android 에뮬레이터에서 PC의 백엔드에 접근할 때 주소는 `http://10.0.2.2:8000`입니다. `127.0.0.1`은 에뮬레이터 자신을 뜻합니다.

## 5. 반영된 주요 기능

- Google 로그인 전용 인증과 앱 복귀용 딥링크
- 방 이름, 여행 일수, 장소 추천 사용 여부를 포함한 방 생성
- 멤버별 가능한 날짜 제출 → 전원 제출 시 자동 후보 계산
- 단일 1등 후보 전원 동의, 공동 1등 후보 전원 투표, 재동률 시 재투표
- 최종 확정된 여행 날짜의 데이터베이스 수준 변경 금지
- 친구 초대 수락 후 방 멤버 추가, 방장 위임, 멤버 나가기, 방장 나가기 시 방 데이터 삭제
- 개인 일정과 확정 여행, 날짜별 기록을 함께 표시하는 달력
- 홈 화면의 방·일정·할 일·최근 기록 동기화
- 날짜별 기록 앨범, 장소별 여러 사진/코멘트, 공개 범위, 좋아요/댓글
- 프로필 사진/닉네임, 이메일 친구 요청, 알림함과 알림/개인정보/로그아웃/탈퇴 설정

## 6. 외부 서비스 연결이 필요한 항목

앱 내부 알림함과 알림 선호도 저장은 바로 사용할 수 있습니다. 그러나 실제 휴대폰 푸시 발송은 Firebase Cloud Messaging 프로젝트와 Android의 `google-services.json`, 서버/Edge Function이 추가로 필요합니다. 실제 이메일 발송도 Resend/SendGrid 같은 발송 서비스와 서버/Edge Function의 API 키가 필요합니다. 자격증명이 없는 상태에서 임의로 연결할 수 없어 UI와 DB 설정 지점까지만 포함했습니다.

사진의 다중 선택, 카메라 촬영, 1920px 축소 및 품질 85 업로드, 진행률, 로컬 임시 초안은 포함되어 있습니다. 사진 EXIF의 날짜·위치를 자동으로 읽는 기능은 기기별 권한과 별도 EXIF 처리 검증이 필요하므로 현재는 사용자가 날짜/장소를 확인해 입력하도록 했습니다.

## 7. 첫 점검 체크리스트

- [ ] 새 SQL 마이그레이션 실행 성공
- [ ] Google Provider와 Redirect URL 설정
- [ ] `flutter pub get` 성공
- [ ] Android 에뮬레이터에서 Google 로그인 성공
- [ ] 프로필 추가 정보 저장 성공
- [ ] 방 생성 및 친구 초대 수락 성공
- [ ] 모든 멤버의 가능한 날짜 제출과 후보 생성 확인
- [ ] 개인 일정이 달력과 홈에 표시되는지 확인
- [ ] 날짜별 기록 및 여러 사진 업로드 확인
- [ ] 로그아웃 후 다시 Google 로그인 확인

