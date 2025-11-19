-- LehrerWM – Supabase Schema

-- 1) teachers
create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  avatar_url text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2) tournaments
create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  start_date timestamptz,
  duel_duration_seconds integer not null default 120,
  status text not null default 'paused' check (status in ('running','paused','finished')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3) matches
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  participant_a_id uuid references public.teachers(id) on delete set null,
  participant_b_id uuid references public.teachers(id) on delete set null,
  round integer not null default 1,
  start_at timestamptz,
  end_at timestamptz,
  status text not null default 'scheduled' check (status in ('scheduled','running','paused','finished')),
  winner_id uuid references public.teachers(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_matches_tournament on public.matches(tournament_id);
create index if not exists idx_matches_status on public.matches(status);

-- 4) votes
create table if not exists public.votes (
  id bigserial primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  choice text not null check (choice in ('A','B')),
  uuid_hmac text not null,
  fingerprint_hmac text,
  created_at timestamptz default now()
);
create index if not exists idx_votes_match on public.votes(match_id);
create unique index if not exists uq_votes_uuid_match on public.votes(match_id, uuid_hmac);
create unique index if not exists uq_votes_fp_match on public.votes(match_id, fingerprint_hmac) where fingerprint_hmac is not null;

-- 5) admins
create table if not exists public.admins (
  id uuid primary key, -- Supabase auth uid
  email text unique not null,
  role text not null default 'admin' check (role in ('admin','superadmin')),
  created_at timestamptz default now()
);

-- 6) audit_logs
create table if not exists public.audit_logs (
  id bigserial primary key,
  actor_type text not null check (actor_type in ('admin','system')),
  actor_id text,
  action text not null,
  details jsonb,
  created_at timestamptz default now()
);

-- Utility views
create or replace view public.match_vote_counts as
select 
  m.id as match_id,
  sum(case when v.choice = 'A' then 1 else 0 end) as votes_a,
  sum(case when v.choice = 'B' then 1 else 0 end) as votes_b
from public.matches m
left join public.votes v on v.match_id = m.id
group by m.id;
