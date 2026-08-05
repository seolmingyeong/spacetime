-- Travel Together full feature migration
-- Run once in Supabase SQL Editor after the original schema.

create extension if not exists pgcrypto;

alter table public.rooms
  add column if not exists trip_days integer not null default 1,
  add column if not exists place_recommendation_enabled boolean not null default true,
  add column if not exists confirmed_date date,
  add column if not exists schedule_locked_at timestamptz,
  add column if not exists schedule_phase text not null default 'collecting';

do $$ begin
  if not exists (select 1 from pg_constraint where conname='rooms_trip_days_range') then
    alter table public.rooms add constraint rooms_trip_days_range check (trip_days between 1 and 30);
  end if;
  if not exists (select 1 from pg_constraint where conname='rooms_schedule_phase_check') then
    alter table public.rooms add constraint rooms_schedule_phase_check
      check (schedule_phase in ('collecting','approval','voting','finalized'));
  end if;
end $$;

alter table public.room_members
  add column if not exists nickname text,
  add column if not exists transport text,
  add column if not exists address text,
  add column if not exists lat double precision,
  add column if not exists lng double precision;

alter table public.date_availabilities
  add column if not exists submitted boolean not null default true,
  add column if not exists submitted_at timestamptz;

create unique index if not exists date_availabilities_room_user_uq
  on public.date_availabilities(room_id,user_id);

-- Shared security helpers avoid recursive room_members RLS policies.
create or replace function public.is_room_member(p_room_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from room_members where room_id=p_room_id and user_id=p_user_id)
$$;
create or replace function public.is_room_owner(p_room_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from room_members where room_id=p_room_id and user_id=p_user_id and role='owner')
$$;

-- Friend relationships ------------------------------------------------------
create table if not exists public.friend_requests(
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted','declined','canceled')),
  created_at timestamptz not null default now(), responded_at timestamptz,
  check(requester_id<>recipient_id)
);
create unique index if not exists friend_requests_pending_pair_uq
  on public.friend_requests(least(requester_id,recipient_id),greatest(requester_id,recipient_id))
  where status='pending';
create table if not exists public.friendships(
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_a,user_b), check(user_a<user_b)
);
create or replace function public.are_friends(a uuid,b uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from friendships where user_a=least(a,b) and user_b=greatest(a,b))
$$;

-- Invitations and notifications -------------------------------------------
create table if not exists public.room_invitations(
 id uuid primary key default gen_random_uuid(), room_id uuid not null references rooms(id) on delete cascade,
 inviter_id uuid not null references profiles(id) on delete cascade,
 invitee_id uuid not null references profiles(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','accepted','declined','canceled')),
 created_at timestamptz not null default now(), responded_at timestamptz
);
create unique index if not exists room_invitations_pending_uq on room_invitations(room_id,invitee_id) where status='pending';

create table if not exists public.notifications(
 id uuid primary key default gen_random_uuid(), recipient_id uuid not null references profiles(id) on delete cascade,
 category text not null, event_type text not null, title text not null, body text not null,
 route text, data jsonb not null default '{}'::jsonb, read_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists notifications_recipient_created_idx on notifications(recipient_id,created_at desc);

create table if not exists public.notification_preferences(
 user_id uuid primary key references profiles(id) on delete cascade,
 all_enabled boolean not null default true, push_enabled boolean not null default true,
 email_enabled boolean not null default true, social_enabled boolean not null default true,
 room_enabled boolean not null default true, travel_schedule_enabled boolean not null default true,
 personal_schedule_enabled boolean not null default true, record_enabled boolean not null default true,
 quiet_hours_enabled boolean not null default false, quiet_start time default '22:00', quiet_end time default '08:00',
 travel_reminder_days integer[] not null default '{7,1,0}', personal_reminder_minutes integer not null default 30,
 email_digest boolean not null default false, updated_at timestamptz not null default now()
);

create table if not exists public.privacy_preferences(
 user_id uuid primary key references profiles(id) on delete cascade,
 email_discoverable boolean not null default true,
 friend_request_scope text not null default 'everyone' check(friend_request_scope in ('everyone','friends_of_friends','nobody')),
 default_record_visibility text not null default 'private' check(default_record_visibility in ('private','friends','public')),
 use_current_location boolean not null default true, use_location_for_midpoint boolean not null default true,
 use_photo_location boolean not null default true, strip_photo_metadata boolean not null default true,
 updated_at timestamptz not null default now()
);
create table if not exists public.blocked_users(
 blocker_id uuid references profiles(id) on delete cascade,
 blocked_id uuid references profiles(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(blocker_id,blocked_id), check(blocker_id<>blocked_id)
);

-- Personal schedules --------------------------------------------------------
create table if not exists public.personal_schedules(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references profiles(id) on delete cascade,
 title text not null check(length(trim(title)) between 1 and 100), schedule_date date not null,
 schedule_time time, is_all_day boolean not null default false, memo text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists personal_schedules_owner_date_idx on personal_schedules(owner_id,schedule_date);

-- Schedule candidates -------------------------------------------------------
create table if not exists public.room_schedule_candidates(
 id uuid primary key default gen_random_uuid(), room_id uuid not null references rooms(id) on delete cascade,
 start_date date not null, end_date date not null, available_member_count integer not null,
 round integer not null default 1, created_at timestamptz not null default now(),
 unique(room_id,start_date,end_date,round)
);
create table if not exists public.schedule_candidate_approvals(
 room_id uuid not null references rooms(id) on delete cascade,
 candidate_id uuid not null references room_schedule_candidates(id) on delete cascade,
 user_id uuid not null references profiles(id) on delete cascade,
 approved boolean not null, responded_at timestamptz not null default now(), primary key(candidate_id,user_id)
);
create table if not exists public.schedule_candidate_votes(
 room_id uuid not null references rooms(id) on delete cascade,
 candidate_id uuid not null references room_schedule_candidates(id) on delete cascade,
 user_id uuid not null references profiles(id) on delete cascade,
 round integer not null, voted_at timestamptz not null default now(), primary key(room_id,user_id,round)
);

-- Date-centred albums -------------------------------------------------------
create table if not exists public.record_albums(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references profiles(id) on delete cascade,
 room_id uuid references rooms(id) on delete set null, record_date date not null, title text not null,
 visibility text not null default 'private' check(visibility in ('private','friends','public')),
 cover_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.record_albums drop constraint if exists record_albums_room_id_fkey;
alter table public.record_albums add constraint record_albums_room_id_fkey
  foreign key(room_id) references public.rooms(id) on delete cascade;
create index if not exists record_albums_date_idx on record_albums(record_date desc);
create table if not exists public.record_entries(
 id uuid primary key default gen_random_uuid(), album_id uuid not null references record_albums(id) on delete cascade,
 place_name text not null, address text, visit_time time, note text, order_index integer not null default 0,
 created_at timestamptz not null default now()
);
create table if not exists public.record_photos(
 id uuid primary key default gen_random_uuid(), album_id uuid not null references record_albums(id) on delete cascade,
 entry_id uuid not null references record_entries(id) on delete cascade,
 owner_id uuid not null references profiles(id) on delete cascade,
 storage_path text not null unique, url text, order_index integer not null default 0,
 is_cover boolean not null default false, created_at timestamptz not null default now()
);
create table if not exists public.album_likes(
 album_id uuid references record_albums(id) on delete cascade,
 user_id uuid references profiles(id) on delete cascade, created_at timestamptz default now(), primary key(album_id,user_id)
);
create table if not exists public.album_comments(
 id uuid primary key default gen_random_uuid(), album_id uuid references record_albums(id) on delete cascade,
 user_id uuid references profiles(id) on delete cascade, content text not null,
 created_at timestamptz not null default now()
);
create or replace function public.can_view_album(p_album uuid,p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from record_albums a where a.id=p_album and (
   a.owner_id=p_user or a.visibility='public' or
   (a.visibility='friends' and public.are_friends(a.owner_id,p_user))))
$$;

-- Atomic room operations ----------------------------------------------------
create or replace function public.create_travel_room(p_name text,p_invite_code text,p_trip_days int,p_place_recommendation_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r rooms; begin
 if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
 insert into rooms(name,invite_code,status,created_by,trip_days,place_recommendation_enabled)
 values(trim(p_name),upper(p_invite_code),'planning',auth.uid(),p_trip_days,p_place_recommendation_enabled) returning * into r;
 insert into room_members(room_id,user_id,role) values(r.id,auth.uid(),'owner');
 return to_jsonb(r)||jsonb_build_object('member_count',1);
end $$;
create or replace function public.join_room_by_code(p_invite_code text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r rooms; begin
 select * into r from rooms where invite_code=upper(trim(p_invite_code));
 if r.id is null then return null; end if;
 insert into room_members(room_id,user_id,role) values(r.id,auth.uid(),'member') on conflict do nothing;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 select user_id,'room','member_joined','새 멤버 참여','새로운 멤버가 '||r.name||' 방에 참여했습니다.',
 '/room/'||r.id,jsonb_build_object('room_id',r.id) from room_members where room_id=r.id and user_id<>auth.uid();
 return to_jsonb(r);
end $$;
create or replace function public.rename_room(p_room_id uuid,p_name text)
returns void language plpgsql security definer set search_path=public as $$ begin
 if not is_room_owner(p_room_id) then raise exception '방장만 변경할 수 있습니다.'; end if;
 update rooms set name=trim(p_name) where id=p_room_id;
end $$;
create or replace function public.transfer_room_ownership(p_room_id uuid,p_new_owner_id uuid)
returns void language plpgsql security definer set search_path=public as $$ begin
 if not is_room_owner(p_room_id) then raise exception '방장만 위임할 수 있습니다.'; end if;
 if not is_room_member(p_room_id,p_new_owner_id) then raise exception '방 멤버가 아닙니다.'; end if;
 update room_members set role='member' where room_id=p_room_id and user_id=auth.uid();
 update room_members set role='owner' where room_id=p_room_id and user_id=p_new_owner_id;
 update rooms set created_by=p_new_owner_id where id=p_room_id;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 values(p_new_owner_id,'room','owner_changed','방장으로 지정되었습니다.','방장 권한이 이전되었습니다.',
 '/room/'||p_room_id,jsonb_build_object('room_id',p_room_id));
end $$;
create or replace function public.leave_room(p_room_id uuid)
returns void language plpgsql security definer set search_path=public as $$ begin
 if is_room_owner(p_room_id) then
   delete from rooms where id=p_room_id;
 else
   delete from room_members where room_id=p_room_id and user_id=auth.uid();
   insert into notifications(recipient_id,category,event_type,title,body,route,data)
   select user_id,'room','member_left','멤버 퇴장','멤버 한 명이 방을 나갔습니다.',
   '/room/'||p_room_id,jsonb_build_object('room_id',p_room_id)
   from room_members where room_id=p_room_id;
 end if;
end $$;

-- Friend RPCs ---------------------------------------------------------------
create or replace function public.find_profile_by_email(p_email text)
returns table(id uuid,nickname text,email text,user_id text,avatar_url text)
language sql security definer set search_path=public as $$
 select p.id,p.nickname,p.email,p.user_id,p.avatar_url from profiles p
 left join privacy_preferences pref on pref.user_id=p.id
 where lower(p.email)=lower(trim(p_email)) and p.id<>auth.uid()
 and coalesce(pref.email_discoverable,true)
 and not exists(select 1 from blocked_users b where
   (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
 limit 1
$$;
create or replace function public.send_friend_request(p_recipient_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare rid uuid; scope text; begin
 if p_recipient_id=auth.uid() then raise exception '본인에게 요청할 수 없습니다.'; end if;
 if are_friends(auth.uid(),p_recipient_id) then raise exception '이미 친구입니다.'; end if;
 if exists(select 1 from blocked_users where
   (blocker_id=auth.uid() and blocked_id=p_recipient_id) or
   (blocker_id=p_recipient_id and blocked_id=auth.uid())) then
   raise exception '친구 요청을 보낼 수 없는 사용자입니다.';
 end if;
 select coalesce(friend_request_scope,'everyone') into scope
 from privacy_preferences where user_id=p_recipient_id;
 scope:=coalesce(scope,'everyone');
 if scope='nobody' then raise exception '이 사용자는 친구 요청을 받지 않습니다.'; end if;
 if scope='friends_of_friends' and not exists(
   select 1 from friendships mine join friendships theirs
   on (case when mine.user_a=auth.uid() then mine.user_b else mine.user_a end)=
      (case when theirs.user_a=p_recipient_id then theirs.user_b else theirs.user_a end)
   where (mine.user_a=auth.uid() or mine.user_b=auth.uid())
     and (theirs.user_a=p_recipient_id or theirs.user_b=p_recipient_id)
 ) then raise exception '공통 친구가 있는 사용자만 요청할 수 있습니다.'; end if;
 insert into friend_requests(requester_id,recipient_id) values(auth.uid(),p_recipient_id) returning id into rid;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 select p_recipient_id,'social','friend_request','새 친구 요청',nickname||'님이 친구 요청을 보냈습니다.',
 '/friends/requests',jsonb_build_object('request_id',rid) from profiles where id=auth.uid();
end $$;
create or replace function public.get_friend_requests()
returns table(id uuid,requester_id uuid,nickname text,email text,avatar_url text,created_at timestamptz)
language sql security definer set search_path=public as $$
 select fr.id,p.id,p.nickname,p.email,p.avatar_url,fr.created_at from friend_requests fr
 join profiles p on p.id=fr.requester_id where fr.recipient_id=auth.uid() and fr.status='pending' order by fr.created_at desc
$$;
create or replace function public.respond_friend_request(p_request_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path=public as $$
declare fr friend_requests; begin
 select * into fr from friend_requests where id=p_request_id and recipient_id=auth.uid() and status='pending' for update;
 if fr.id is null then raise exception '유효한 요청이 아닙니다.'; end if;
 update friend_requests set status=case when p_accept then 'accepted' else 'declined' end,responded_at=now() where id=fr.id;
 if p_accept then insert into friendships(user_a,user_b) values(least(fr.requester_id,fr.recipient_id),greatest(fr.requester_id,fr.recipient_id)) on conflict do nothing; end if;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 values(fr.requester_id,'social',case when p_accept then 'friend_accepted' else 'friend_declined' end,
 case when p_accept then '친구 요청 수락' else '친구 요청 거절' end,
 case when p_accept then '친구 요청이 수락되었습니다.' else '친구 요청이 거절되었습니다.' end,
 '/friends',jsonb_build_object('request_id',fr.id));
end $$;
create or replace function public.get_my_friends()
returns table(id uuid,nickname text,email text,user_id text,avatar_url text)
language sql security definer set search_path=public as $$
 select p.id,p.nickname,p.email,p.user_id,p.avatar_url from friendships f join profiles p
 on p.id=case when f.user_a=auth.uid() then f.user_b else f.user_a end
 where f.user_a=auth.uid() or f.user_b=auth.uid() order by p.nickname
$$;
create or replace function public.remove_friend(p_friend_id uuid)
returns void language sql security definer set search_path=public as $$
 delete from friendships where user_a=least(auth.uid(),p_friend_id) and user_b=greatest(auth.uid(),p_friend_id)
$$;

-- Room invite RPCs ----------------------------------------------------------
create or replace function public.invite_friend_to_room(p_room_id uuid,p_invitee_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare iid uuid; rname text; begin
 if not is_room_owner(p_room_id) then raise exception '방장만 초대할 수 있습니다.'; end if;
 if not are_friends(auth.uid(),p_invitee_id) then raise exception '친구만 초대할 수 있습니다.'; end if;
 if is_room_member(p_room_id,p_invitee_id) then raise exception '이미 참여 중입니다.'; end if;
 insert into room_invitations(room_id,inviter_id,invitee_id) values(p_room_id,auth.uid(),p_invitee_id) returning id into iid;
 select name into rname from rooms where id=p_room_id;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 values(p_invitee_id,'room','room_invitation','새 방 초대',rname||' 방에 초대되었습니다.',
 '/room-invitations',jsonb_build_object('invitation_id',iid,'room_id',p_room_id));
end $$;
create or replace function public.get_room_invitations()
returns table(id uuid,room_id uuid,room_name text,inviter_id uuid,inviter_name text,trip_days int,member_count bigint,created_at timestamptz)
language sql security definer set search_path=public as $$
 select i.id,r.id,r.name,p.id,p.nickname,r.trip_days,(select count(*) from room_members m where m.room_id=r.id),i.created_at
 from room_invitations i join rooms r on r.id=i.room_id join profiles p on p.id=i.inviter_id
 where i.invitee_id=auth.uid() and i.status='pending' order by i.created_at desc
$$;
create or replace function public.respond_room_invitation(p_invitation_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path=public as $$
declare i room_invitations; locked boolean; begin
 select * into i from room_invitations where id=p_invitation_id and invitee_id=auth.uid() and status='pending' for update;
 if i.id is null then raise exception '유효한 초대가 아닙니다.'; end if;
 update room_invitations set status=case when p_accept then 'accepted' else 'declined' end,responded_at=now() where id=i.id;
 if p_accept then
   insert into room_members(room_id,user_id,role) values(i.room_id,auth.uid(),'member') on conflict do nothing;
   select schedule_locked_at is not null into locked from rooms where id=i.room_id;
   if not locked then
     delete from room_schedule_candidates where room_id=i.room_id;
     update rooms set schedule_phase='collecting' where id=i.room_id;
   end if;
 end if;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 values(i.inviter_id,'room',case when p_accept then 'invitation_accepted' else 'invitation_declined' end,
 '방 초대 응답',case when p_accept then '친구가 방 초대를 수락했습니다.' else '친구가 방 초대를 거절했습니다.' end,
 '/room/'||i.room_id,jsonb_build_object('room_id',i.room_id));
end $$;

-- Schedule algorithm --------------------------------------------------------
create or replace function public.recalculate_schedule_candidates(p_room_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare members_count int; submitted_count int; days int; min_d date; max_d date; top_count int; candidate_count int; begin
 if not is_room_member(p_room_id) then raise exception '방 멤버가 아닙니다.'; end if;
 if exists(select 1 from rooms where id=p_room_id and schedule_locked_at is not null) then return; end if;
 select count(*) into members_count from room_members where room_id=p_room_id;
 select count(*) into submitted_count from date_availabilities where room_id=p_room_id and submitted;
 if members_count=0 or submitted_count<members_count then return; end if;
 select trip_days into days from rooms where id=p_room_id;
 select min(u.available_date),max(u.available_date) into min_d,max_d
 from date_availabilities da
 cross join unnest(da.available_dates) as u(available_date)
 where da.room_id=p_room_id and da.submitted;
 if min_d is null then return; end if;
 delete from room_schedule_candidates where room_id=p_room_id;
 with windows as (
   select g::date s,(g::date+(days-1))::date e from generate_series(min_d,max_d-(days-1),interval '1 day') g
 ), scored as (
   select w.s,w.e,count(da.user_id)::int score from windows w cross join date_availabilities da
   where da.room_id=p_room_id and da.submitted and not exists(
     select 1 from generate_series(w.s,w.e,interval '1 day') dd where not (dd::date=any(da.available_dates)))
   group by w.s,w.e
 ), best as (select max(score) score from scored)
 insert into room_schedule_candidates(room_id,start_date,end_date,available_member_count)
 select p_room_id,s.s,s.e,s.score from scored s,best b where s.score=b.score and s.score>0;
 select count(*) into candidate_count from room_schedule_candidates where room_id=p_room_id;
 update rooms set schedule_phase=case when candidate_count=1 then 'approval' else 'voting' end where id=p_room_id;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 select user_id,'travel_schedule',case when candidate_count=1 then 'candidate_approval' else 'candidate_vote' end,
 case when candidate_count=1 then '여행 날짜 동의 요청' else '여행 날짜 투표 요청' end,
 case when candidate_count=1 then '모두가 날짜 후보에 동의하면 일정이 확정됩니다.' else '공동 1등 날짜 후보에 투표해 주세요.' end,
 '/room/'||p_room_id,jsonb_build_object('room_id',p_room_id) from room_members where room_id=p_room_id;
end $$;
create or replace function public.finalize_room_schedule(p_room_id uuid,p_candidate_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare c room_schedule_candidates; begin
 select * into c from room_schedule_candidates where id=p_candidate_id and room_id=p_room_id;
 update rooms set start_date=c.start_date,end_date=c.end_date,confirmed_date=current_date,
 schedule_locked_at=now(),schedule_phase='finalized',status='traveling' where id=p_room_id and schedule_locked_at is null;
 insert into notifications(recipient_id,category,event_type,title,body,route,data)
 select user_id,'travel_schedule','schedule_finalized','여행 일정 확정',
 c.start_date||'부터 '||c.end_date||'까지로 여행 일정이 확정되었습니다.',
 '/room/'||p_room_id,jsonb_build_object('room_id',p_room_id) from room_members where room_id=p_room_id;
end $$;
create or replace function public.respond_schedule_candidate(p_room_id uuid,p_candidate_id uuid,p_approved boolean)
returns void language plpgsql security definer set search_path=public as $$
declare total int; yes_count int; begin
 if not is_room_member(p_room_id) then raise exception '방 멤버가 아닙니다.'; end if;
 insert into schedule_candidate_approvals(room_id,candidate_id,user_id,approved)
 values(p_room_id,p_candidate_id,auth.uid(),p_approved)
 on conflict(candidate_id,user_id) do update set approved=excluded.approved,responded_at=now();
 if not p_approved then
   delete from room_schedule_candidates where room_id=p_room_id;
   update date_availabilities set submitted=false where room_id=p_room_id and user_id=auth.uid();
   update rooms set schedule_phase='collecting' where id=p_room_id;
   return;
 end if;
 select count(*) into total from room_members where room_id=p_room_id;
 select count(*) into yes_count from schedule_candidate_approvals where candidate_id=p_candidate_id and approved;
 if yes_count=total then perform finalize_room_schedule(p_room_id,p_candidate_id); end if;
end $$;
create or replace function public.vote_schedule_candidate(p_room_id uuid,p_candidate_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare rnd int; total int; voted int; max_votes int; winners int; winner uuid; begin
 if not is_room_member(p_room_id) then raise exception '방 멤버가 아닙니다.'; end if;
 select round into rnd from room_schedule_candidates where id=p_candidate_id and room_id=p_room_id;
 insert into schedule_candidate_votes(room_id,candidate_id,user_id,round) values(p_room_id,p_candidate_id,auth.uid(),rnd)
 on conflict(room_id,user_id,round) do update set candidate_id=excluded.candidate_id,voted_at=now();
 select count(*) into total from room_members where room_id=p_room_id;
 select count(*) into voted from schedule_candidate_votes where room_id=p_room_id and round=rnd;
 if voted<total then return; end if;
 select max(c) into max_votes from (select count(*) c from schedule_candidate_votes where room_id=p_room_id and round=rnd group by candidate_id) q;
 select count(*),min(candidate_id) into winners,winner from (
  select candidate_id,count(*) c from schedule_candidate_votes where room_id=p_room_id and round=rnd group by candidate_id having count(*)=max_votes) q;
 if winners=1 then perform finalize_room_schedule(p_room_id,winner); else
   delete from room_schedule_candidates where room_id=p_room_id and id not in(
    select candidate_id from schedule_candidate_votes where room_id=p_room_id and round=rnd group by candidate_id having count(*)=max_votes);
   update room_schedule_candidates set round=rnd+1 where room_id=p_room_id;
   delete from schedule_candidate_votes where room_id=p_room_id and round=rnd;
 end if;
end $$;
create or replace function public.get_schedule_candidates(p_room_id uuid)
returns table(id uuid,room_id uuid,start_date date,end_date date,available_member_count int,round int,vote_count bigint,my_approval boolean,has_my_vote boolean)
language sql security definer set search_path=public as $$
 select c.id,c.room_id,c.start_date,c.end_date,c.available_member_count,c.round,
 (select count(*) from schedule_candidate_votes v where v.candidate_id=c.id),
 (select approved from schedule_candidate_approvals a where a.candidate_id=c.id and a.user_id=auth.uid()),
 exists(select 1 from schedule_candidate_votes v where v.candidate_id=c.id and v.user_id=auth.uid() and v.round=c.round)
 from room_schedule_candidates c where c.room_id=p_room_id and is_room_member(p_room_id) order by c.start_date
$$;

create or replace function public.prevent_finalized_schedule_change()
returns trigger language plpgsql as $$ begin
 if old.schedule_locked_at is not null and
   (new.start_date is distinct from old.start_date or new.end_date is distinct from old.end_date or new.schedule_locked_at is distinct from old.schedule_locked_at)
 then raise exception '확정된 여행 일정은 변경할 수 없습니다.'; end if;
 return new;
end $$;
drop trigger if exists rooms_schedule_lock_trigger on rooms;
create trigger rooms_schedule_lock_trigger before update on rooms for each row execute function prevent_finalized_schedule_change();

-- Album deletion removes private Storage objects first.
create or replace function public.delete_record_album(p_album_id uuid)
returns void language plpgsql security definer set search_path=public as $$ begin
 if not exists(select 1 from record_albums where id=p_album_id and owner_id=auth.uid()) then raise exception '삭제 권한이 없습니다.'; end if;
 delete from storage.objects where bucket_id='record-media' and name in(select storage_path from record_photos where album_id=p_album_id);
 delete from record_albums where id=p_album_id;
end $$;

create or replace function public.export_my_data()
returns jsonb language sql security definer set search_path=public as $$
 select jsonb_build_object(
  'profile',(select to_jsonb(p) from profiles p where p.id=auth.uid()),
  'personal_schedules',(select coalesce(jsonb_agg(s),'[]'::jsonb) from personal_schedules s where s.owner_id=auth.uid()),
  'friends',(select coalesce(jsonb_agg(f),'[]'::jsonb) from get_my_friends() f),
  'rooms',(select coalesce(jsonb_agg(r),'[]'::jsonb) from rooms r join room_members m on m.room_id=r.id where m.user_id=auth.uid()),
  'record_albums',(select coalesce(jsonb_agg(a),'[]'::jsonb) from record_albums a where a.owner_id=auth.uid())
 )
$$;

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path=public,auth,storage as $$ begin
 if exists(select 1 from public.room_members where user_id=auth.uid() and role='owner') then
  raise exception '방장인 방을 위임하거나 삭제한 후 탈퇴할 수 있습니다.';
 end if;
 delete from storage.objects where owner_id=auth.uid()::text;
 delete from auth.users where id=auth.uid();
end $$;

-- RLS -----------------------------------------------------------------------
alter table friend_requests enable row level security; alter table friendships enable row level security;
alter table room_invitations enable row level security; alter table notifications enable row level security;
alter table notification_preferences enable row level security; alter table privacy_preferences enable row level security;
alter table blocked_users enable row level security; alter table personal_schedules enable row level security;
alter table room_schedule_candidates enable row level security; alter table schedule_candidate_approvals enable row level security;
alter table schedule_candidate_votes enable row level security; alter table record_albums enable row level security;
alter table record_entries enable row level security; alter table record_photos enable row level security;
alter table album_likes enable row level security; alter table album_comments enable row level security;

drop policy if exists personal_schedules_own on personal_schedules;
create policy personal_schedules_own on personal_schedules for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists notifications_own on notifications;
create policy notifications_own on notifications for select using(recipient_id=auth.uid());
drop policy if exists notifications_update_own on notifications;
create policy notifications_update_own on notifications for update using(recipient_id=auth.uid());
drop policy if exists notification_preferences_own on notification_preferences;
create policy notification_preferences_own on notification_preferences for all using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists privacy_preferences_own on privacy_preferences;
create policy privacy_preferences_own on privacy_preferences for all using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists blocked_users_own on blocked_users;
create policy blocked_users_own on blocked_users for all using(blocker_id=auth.uid()) with check(blocker_id=auth.uid());
drop policy if exists candidates_room on room_schedule_candidates;
create policy candidates_room on room_schedule_candidates for select using(is_room_member(room_id));
drop policy if exists approvals_room on schedule_candidate_approvals;
create policy approvals_room on schedule_candidate_approvals for select using(is_room_member(room_id));
drop policy if exists votes_room on schedule_candidate_votes;
create policy votes_room on schedule_candidate_votes for select using(is_room_member(room_id));
drop policy if exists albums_visible on record_albums;
create policy albums_visible on record_albums for select using(can_view_album(id));
drop policy if exists albums_owner_write on record_albums;
create policy albums_owner_write on record_albums for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists entries_visible on record_entries;
create policy entries_visible on record_entries for select using(can_view_album(album_id));
drop policy if exists entries_owner_write on record_entries;
create policy entries_owner_write on record_entries for all using(exists(select 1 from record_albums a where a.id=album_id and a.owner_id=auth.uid())) with check(exists(select 1 from record_albums a where a.id=album_id and a.owner_id=auth.uid()));
drop policy if exists photos_visible on record_photos;
create policy photos_visible on record_photos for select using(can_view_album(album_id));
drop policy if exists photos_owner_write on record_photos;
create policy photos_owner_write on record_photos for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists album_likes_visible on album_likes;
create policy album_likes_visible on album_likes for select using(can_view_album(album_id));
drop policy if exists album_likes_own on album_likes;
create policy album_likes_own on album_likes for all using(user_id=auth.uid()) with check(user_id=auth.uid() and can_view_album(album_id));
drop policy if exists album_comments_visible on album_comments;
create policy album_comments_visible on album_comments for select using(can_view_album(album_id));
drop policy if exists album_comments_own on album_comments;
create policy album_comments_own on album_comments for all using(user_id=auth.uid()) with check(user_id=auth.uid() and can_view_album(album_id));

-- Existing room tables: authenticated room members only.
drop policy if exists rooms_select on rooms; create policy rooms_select on rooms for select using(is_room_member(id));
drop policy if exists rooms_insert on rooms; create policy rooms_insert on rooms for insert with check(created_by=auth.uid());
drop policy if exists rooms_update on rooms; create policy rooms_update on rooms for update using(is_room_owner(id));
drop policy if exists room_members_select on room_members; create policy room_members_select on room_members for select using(is_room_member(room_id));
drop policy if exists room_members_insert on room_members; create policy room_members_insert on room_members for insert with check(user_id=auth.uid() or is_room_owner(room_id));
drop policy if exists room_members_update_own on room_members; create policy room_members_update_own on room_members for update using(user_id=auth.uid() or is_room_owner(room_id));
drop policy if exists room_members_delete_own on room_members; create policy room_members_delete_own on room_members for delete using(user_id=auth.uid() or is_room_owner(room_id));

alter table places enable row level security;
alter table courses enable row level security;
alter table course_places enable row level security;
alter table date_availabilities enable row level security;
drop policy if exists "누구나 장소를 볼 수 있음" on places;
drop policy if exists "누구나 장소를 추가할 수 있음" on places;
drop policy if exists places_room_select on places;
create policy places_room_select on places for select using(is_room_member(room_id));
drop policy if exists places_room_insert on places;
create policy places_room_insert on places for insert with check(is_room_member(room_id) and added_by=auth.uid());
drop policy if exists places_room_update on places;
create policy places_room_update on places for update using(is_room_member(room_id));
drop policy if exists courses_room_access on courses;
create policy courses_room_access on courses for all using(is_room_member(room_id)) with check(is_room_member(room_id));
drop policy if exists course_places_room_access on course_places;
create policy course_places_room_access on course_places for all
using(exists(select 1 from courses c where c.id=course_id and is_room_member(c.room_id)))
with check(exists(select 1 from courses c where c.id=course_id and is_room_member(c.room_id)));
drop policy if exists "자신의 가용 날짜 관리 가능" on date_availabilities;
drop policy if exists date_availabilities_select on date_availabilities;
drop policy if exists date_availability_room_select on date_availabilities;
create policy date_availability_room_select on date_availabilities for select using(is_room_member(room_id));
drop policy if exists date_availability_own_write on date_availabilities;
create policy date_availability_own_write on date_availabilities for all
using(user_id=auth.uid() and is_room_member(room_id))
with check(user_id=auth.uid() and is_room_member(room_id));

-- Storage buckets. Avatars are public; record media is protected by signed URLs/RLS.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('record-media','record-media',false,10485760,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
drop policy if exists avatar_upload_own on storage.objects;
create policy avatar_upload_own on storage.objects for insert to authenticated with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists avatar_update_own on storage.objects;
create policy avatar_update_own on storage.objects for update to authenticated using(bucket_id='avatars' and owner_id=auth.uid()::text);
drop policy if exists record_media_owner_insert on storage.objects;
create policy record_media_owner_insert on storage.objects for insert to authenticated with check(bucket_id='record-media' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists record_media_visible on storage.objects;
create policy record_media_visible on storage.objects for select to authenticated using(
 bucket_id='record-media' and can_view_album(((storage.foldername(name))[2])::uuid));
drop policy if exists record_media_owner_delete on storage.objects;
create policy record_media_owner_delete on storage.objects for delete to authenticated using(bucket_id='record-media' and owner_id=auth.uid()::text);

-- Do not expose profile email in ordinary profile joins.
revoke select on public.profiles from anon,authenticated;
grant select(id,nickname,user_id,avatar_url) on public.profiles to authenticated;
grant update(nickname,avatar_url,email) on public.profiles to authenticated;

grant execute on all functions in schema public to authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;

-- Keep the column-level profile restriction after the broad table grant.
revoke select on public.profiles from anon,authenticated;
grant select(id,nickname,user_id,avatar_url) on public.profiles to authenticated;
grant insert,update on public.profiles to authenticated;
