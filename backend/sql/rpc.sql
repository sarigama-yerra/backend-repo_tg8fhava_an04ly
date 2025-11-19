-- Helper: verify recaptcha (if you deploy as Edge Function, move there)
-- Here we keep RPCs pure SQL/PLpgSQL; reCAPTCHA check should be done in an Edge Function wrapper.

-- compute_winner_and_advance: determines winner of a finished match and creates next round if needed
create or replace function public.compute_winner_and_advance(p_match_id uuid)
returns void
language plpgsql
as $$
declare
  v_match record;
  v_counts record;
  v_winner uuid;
  v_next_match_id uuid;
  v_tournament_id uuid;
  v_round integer;
  v_opponent_match_id uuid;
begin
  select * into v_match from public.matches where id = p_match_id;
  if not found then
    raise exception 'match not found';
  end if;

  -- Count votes
  select
    sum(case when choice = 'A' then 1 else 0 end) as votes_a,
    sum(case when choice = 'B' then 1 else 0 end) as votes_b
  into v_counts
  from public.votes where match_id = p_match_id;

  if coalesce(v_counts.votes_a,0) >= coalesce(v_counts.votes_b,0) then
    v_winner := v_match.participant_a_id;
  else
    v_winner := v_match.participant_b_id;
  end if;

  update public.matches
    set status = 'finished', winner_id = v_winner, updated_at = now()
    where id = p_match_id;

  -- TODO: Build next round logic (simplified placeholder omitted here)
end;
$$;

-- Secure cast_vote via RPC (expects pre-HMACed identifiers)
create or replace function public.cast_vote(
  p_match_id uuid,
  p_choice text,
  p_uuid_hmac text,
  p_fingerprint_hmac text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Validate match window
  if not exists (
    select 1 from public.matches m
    where m.id = p_match_id
      and m.status = 'running'
      and m.start_at is not null
      and m.end_at is not null
      and m.start_at <= now()
      and now() < m.end_at
  ) then
    raise exception 'match not running';
  end if;

  -- Enforce one vote per uuid/fingerprint per match
  if exists (select 1 from public.votes where match_id = p_match_id and uuid_hmac = p_uuid_hmac) then
    raise exception 'already voted (uuid)';
  end if;
  if p_fingerprint_hmac is not null and exists (
    select 1 from public.votes where match_id = p_match_id and fingerprint_hmac = p_fingerprint_hmac
  ) then
    raise exception 'already voted (fingerprint)';
  end if;

  insert into public.votes(match_id, choice, uuid_hmac, fingerprint_hmac)
  values (p_match_id, p_choice, p_uuid_hmac, p_fingerprint_hmac);

  -- Notify realtime
  perform pg_notify('matches', json_build_object('type','vote','match_id', p_match_id)::text);
end;
$$;

-- Admin helpers: create tournament, build bracket, control matches
-- For simplicity, provide minimal helpers. You can extend as needed.

create or replace function public.create_tournament(p_name text, p_duel_seconds int)
returns uuid
language plpgsql
security definer
as $$
declare v_id uuid;
begin
  insert into public.tournaments(name, duel_duration_seconds, status)
  values (p_name, p_duel_seconds, 'paused') returning id into v_id;
  return v_id;
end; $$;

create or replace function public.build_bracket(p_tournament_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_teacher_ids uuid[];
  v_count int;
  v_i int;
  v_a uuid;
  v_b uuid;
  v_round int := 1;
  v_bye uuid;
begin
  -- Collect all teachers
  select array_agg(id order by name) into v_teacher_ids from public.teachers;
  v_count := coalesce(array_length(v_teacher_ids,1),0);
  if v_count < 2 then
    raise exception 'not enough teachers';
  end if;

  -- Handle bye if odd
  if mod(v_count,2) = 1 then
    v_bye := v_teacher_ids[v_count];
    v_count := v_count - 1;
  end if;

  v_i := 1;
  while v_i <= v_count loop
    v_a := v_teacher_ids[v_i];
    v_b := v_teacher_ids[v_i+1];
    insert into public.matches(tournament_id, participant_a_id, participant_b_id, round, status)
    values (p_tournament_id, v_a, v_b, v_round, 'scheduled');
    v_i := v_i + 2;
  end loop;

  if v_bye is not null then
    -- create a phantom match with immediate winner
    insert into public.matches(tournament_id, participant_a_id, participant_b_id, round, status, winner_id)
    values (p_tournament_id, v_bye, null, 0, 'finished', v_bye);
  end if;
end; $$;

create or replace function public.start_match(p_match_id uuid)
returns void
language sql
security definer
as $$
  update public.matches m
    set status='running', start_at = now(), end_at = now() + make_interval(secs => (select duel_duration_seconds from public.tournaments t where t.id = m.tournament_id)), updated_at = now()
  where m.id = p_match_id;
$$;

create or replace function public.pause_match(p_match_id uuid)
returns void language sql security definer as $$
  update public.matches set status='paused', updated_at = now() where id = p_match_id;
$$;

create or replace function public.reset_match(p_match_id uuid)
returns void language plpgsql security definer as $$
begin
  delete from public.votes where match_id = p_match_id;
  update public.matches set status='scheduled', start_at = null, end_at = null, winner_id=null, updated_at = now() where id = p_match_id;
end; $$;
