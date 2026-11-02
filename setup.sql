-- =====================================================================
-- MOTOREEZ — database setup
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- It is safe to run more than once.
--
-- Ready to run: the workshop login is already filled in on the last line.

-- Only logins listed in `members` can read or write anything.
-- =====================================================================

-- Everything the app keeps, one row per key, exactly as the app names it.
create table if not exists public.kv (
  key        text primary key,
  value      jsonb,
  updated_at timestamptz not null default clock_timestamp()
);

-- Invoice and job-card counters live in their own table so that two phones
-- finalising a bill at the same moment can never get the same number.
create table if not exists public.counters (
  series text    not null,
  fy     text    not null,
  n      integer not null default 0,
  primary key (series, fy)
);

-- The logins allowed in. Kept separate so that even if sign-ups are left
-- open by mistake, a stranger who signs up still sees nothing.
create table if not exists public.members (
  email text primary key
);

-- Every write stamps the row with the server's own clock, so phones can
-- ask "what changed since I last looked" without trusting their clocks.
create or replace function public.kv_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end $$;
drop trigger if exists kv_touch on public.kv;
create trigger kv_touch before insert or update on public.kv
  for each row execute function public.kv_touch();

-- Is the signed-in login on the members list?
create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- Next number in a series, atomically. p_floor lets the app say "I already
-- know about number N" so a restored backup can never cause a repeat.
create or replace function public.next_number(p_series text, p_fy text, p_floor integer default 0)
returns integer language plpgsql as $$
declare v integer;
begin
  if not public.is_member() then raise exception 'not allowed'; end if;
  insert into public.counters (series, fy, n)
  values (p_series, p_fy, greatest(coalesce(p_floor, 0), 0) + 1)
  on conflict (series, fy)
  do update set n = greatest(public.counters.n, excluded.n - 1) + 1
  returning n into v;
  return v;
end $$;

-- Add one item to a list without reading it first, so two people posting
-- in the same chat at the same moment both keep their message.
create or replace function public.kv_append(p_key text, p_item jsonb)
returns jsonb language plpgsql as $$
declare v jsonb;
begin
  if not public.is_member() then raise exception 'not allowed'; end if;
  insert into public.kv (key, value) values (p_key, jsonb_build_array(p_item))
  on conflict (key) do update set value =
    (case when jsonb_typeof(public.kv.value) = 'array' then public.kv.value else '[]'::jsonb end)
    || jsonb_build_array(p_item)
  returning value into v;
  return v;
end $$;

-- Merge a few top-level fields into an object without overwriting the rest.
create or replace function public.kv_merge(p_key text, p_patch jsonb)
returns jsonb language plpgsql as $$
declare v jsonb;
begin
  if not public.is_member() then raise exception 'not allowed'; end if;
  insert into public.kv (key, value) values (p_key, p_patch)
  on conflict (key) do update set value =
    (case when jsonb_typeof(public.kv.value) = 'object' then public.kv.value else '{}'::jsonb end)
    || p_patch
  returning value into v;
  return v;
end $$;

-- Row security: members only, on everything.
alter table public.kv       enable row level security;
alter table public.counters enable row level security;
alter table public.members  enable row level security;   -- no policy: not readable from the app at all

drop policy if exists "members only" on public.kv;
create policy "members only" on public.kv
  for all to authenticated using (public.is_member()) with check (public.is_member());

drop policy if exists "members only" on public.counters;
create policy "members only" on public.counters
  for all to authenticated using (public.is_member()) with check (public.is_member());

revoke all on function public.next_number(text, text, integer) from public, anon;
revoke all on function public.kv_append(text, jsonb)            from public, anon;
revoke all on function public.kv_merge(text, jsonb)             from public, anon;
grant execute on function public.next_number(text, text, integer) to authenticated;
grant execute on function public.kv_append(text, jsonb)            to authenticated;
grant execute on function public.kv_merge(text, jsonb)             to authenticated;
grant execute on function public.is_member()                       to authenticated;

-- The workshop login allowed in. Add more lines like this for more logins.
insert into public.members (email) values ('kunal@motoreez.com') on conflict do nothing;
