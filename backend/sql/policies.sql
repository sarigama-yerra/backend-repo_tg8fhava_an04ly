-- Enable RLS
alter table public.teachers enable row level security;
alter table public.tournaments enable row level security;
alter table public.matches enable row level security;
alter table public.votes enable row level security;
alter table public.admins enable row level security;
alter table public.audit_logs enable row level security;

-- Basic read for everyone (public data)
create policy "Public read teachers" on public.teachers
  for select using (true);

create policy "Public read tournaments" on public.tournaments
  for select using (true);

create policy "Public read matches" on public.matches
  for select using (true);

create policy "Public read votes (aggregated via view)" on public.votes
  for select using (true);

create policy "Admins can manage teachers" on public.teachers
  for all using (
    exists (
      select 1 from public.admins a
      where a.id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.admins a
      where a.id = auth.uid()
    )
  );

create policy "Admins can manage tournaments" on public.tournaments
  for all using (
    exists (select 1 from public.admins a where a.id = auth.uid())
  ) with check (
    exists (select 1 from public.admins a where a.id = auth.uid())
  );

create policy "Admins can manage matches" on public.matches
  for all using (
    exists (select 1 from public.admins a where a.id = auth.uid())
  ) with check (
    exists (select 1 from public.admins a where a.id = auth.uid())
  );

-- Votes: keine direkten Inserts aus dem Client, nur via RPC/Edge-Func
create policy "No direct vote insert" on public.votes
  for insert with check (false);
create policy "No direct vote update" on public.votes
  for update using (false) with check (false);
create policy "No direct vote delete" on public.votes
  for delete using (false);

-- Admins can read audit logs
create policy "Admins read audit logs" on public.audit_logs
  for select using (
    exists (select 1 from public.admins a where a.id = auth.uid())
  );

-- Admins manage admins (superadmin only for dangerous ops could be enforced via RPC)
create policy "Admins read admins" on public.admins
  for select using (
    exists (select 1 from public.admins a where a.id = auth.uid())
  );
