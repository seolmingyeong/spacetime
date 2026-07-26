-- ============================================================
-- Travel Together App - Supabase Schema (초안)
-- Supabase 프로젝트 생성 후 SQL Editor 에서 실행하세요.
-- TODO(team): 실제 기능 확정 후 컬럼/제약조건/RLS 정책을 다듬어야 합니다.
-- ============================================================

-- 1. 프로필 (auth.users 와 1:1 연결)
create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null,
  email text not null,
  avatar_url text,
  friend_code text unique, -- 개인 코드(친구 추가용)
  created_at timestamptz not null default now()
);

-- 2. 방 (여행 그룹)
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'planning', -- planning | traveling | completed
  invite_code text unique,
  start_date date,
  end_date date,
  cover_image_url text,
  created_by uuid references profiles (id),
  created_at timestamptz not null default now()
);

-- 3. 방 멤버
create table if not exists room_members (
  room_id uuid references rooms (id) on delete cascade,
  user_id uuid references profiles (id) on delete cascade,
  role text not null default 'member', -- owner | member
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

-- 4. 일정
create table if not exists schedules (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms (id) on delete cascade,
  title text not null,
  date date not null,
  time time,
  location text,
  status text not null default 'voting', -- voting | confirmed
  created_by uuid references profiles (id),
  created_at timestamptz not null default now()
);

-- 5. 일정 투표 (가능한 날짜/시간에 대한 멤버 투표)
create table if not exists schedule_votes (
  schedule_id uuid references schedules (id) on delete cascade,
  user_id uuid references profiles (id) on delete cascade,
  vote text not null default 'yes', -- yes | no | maybe
  created_at timestamptz not null default now(),
  primary key (schedule_id, user_id)
);

-- 6. 장소 (추천/저장된 장소)
create table if not exists places (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms (id) on delete cascade,
  name text not null,
  category text,
  lat double precision not null,
  lng double precision not null,
  rating numeric,
  price_level int,
  added_by uuid references profiles (id),
  created_at timestamptz not null default now()
);

-- 7. 장소 투표
create table if not exists place_votes (
  place_id uuid references places (id) on delete cascade,
  user_id uuid references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (place_id, user_id)
);

-- 8. 코스 (AI로 계산된 최적 동선)
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms (id) on delete cascade,
  name text,
  total_distance_km numeric,
  total_duration_min numeric,
  created_at timestamptz not null default now()
);

create table if not exists course_places (
  course_id uuid references courses (id) on delete cascade,
  place_id uuid references places (id) on delete cascade,
  order_index int not null,
  primary key (course_id, place_id)
);

-- 9. 기록 (여행 중/후 남기는 사진, 메모)
create table if not exists records (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms (id) on delete cascade,
  place_name text not null,
  memo text,
  image_url text,
  created_by uuid references profiles (id),
  like_count int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists record_comments (
  id uuid primary key default gen_random_uuid(),
  record_id uuid references records (id) on delete cascade,
  user_id uuid references profiles (id),
  content text not null,
  created_at timestamptz not null default now()
);

-- 10. 친구
create table if not exists friends (
  user_id uuid references profiles (id) on delete cascade,
  friend_id uuid references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);

-- ------------------------------------------------------------
-- Row Level Security (RLS) - 기본 뼈대만 활성화.
-- TODO(team): 방 멤버만 방 데이터에 접근 가능하도록 정책을 구체화해야 합니다.
-- ------------------------------------------------------------
alter table profiles enable row level security;
alter table rooms enable row level security;
alter table room_members enable row level security;
alter table schedules enable row level security;
alter table places enable row level security;
alter table records enable row level security;
alter table friends enable row level security;

-- 예시 정책: 로그인한 사용자는 자기 프로필만 수정 가능
create policy "profiles_select_all" on profiles for select using (true);
create policy "profiles_update_own" on profiles for update using (auth.uid() = id);
