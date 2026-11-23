-- ===================================================================
-- REFERENCE DATA: parts catalogue, bikes it fits, fluid and engine tables
-- Run once in Supabase (SQL editor). Safe to run again.
-- Edit rows in the Table Editor; phones pick up the change on their own
-- because every edit raises the version number in ref_data.
-- ===================================================================
create table if not exists public.ref_data (
  key        text primary key,          -- 'catalogue', 'bike_fluids', 'bike_engine'
  ver        integer not null default 1,
  data       jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.catalogue_bikes (
  id          integer primary key,
  make        text not null,
  model       text not null,
  version     text not null default '',
  engine      text not null default '',
  source_name text not null default '',
  matched     boolean not null default false
);
create table if not exists public.catalogue_parts (
  brand        text not null,                 -- short name: RE, Bajaj
  part_no      text not null,
  alternates   text not null default '',      -- other part numbers, separated by |
  description  text not null default '',
  category     text not null default '',
  sub_category text not null default '',
  mrp          numeric(12,2) not null default 0,  -- rupees, GST included
  discontinued boolean not null default false,    -- no longer supplied (NLS)
  unit         text not null default 'piece',
  fits         integer[] not null default '{}',   -- ids from catalogue_bikes
  updated_at   timestamptz not null default now(),
  primary key (brand, part_no)
);

-- a new version number whenever the data changes, so phones refresh their copy
create or replace function public.ref_data_bump() returns trigger
language plpgsql as $$
begin
  if new.data is distinct from old.data then
    new.ver := old.ver + 1; new.updated_at := now();
  end if;
  return new;
end $$;
drop trigger if exists ref_data_bump on public.ref_data;
create trigger ref_data_bump before update on public.ref_data
  for each row execute function public.ref_data_bump();

create or replace function public.catalogue_bump() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.ref_data (key, ver, data) values ('catalogue', 1, '{}'::jsonb)
  on conflict (key) do update set ver = public.ref_data.ver + 1, updated_at = now();
  return null;
end $$;
drop trigger if exists catalogue_parts_bump on public.catalogue_parts;
create trigger catalogue_parts_bump after insert or update or delete on public.catalogue_parts
  for each statement execute function public.catalogue_bump();
drop trigger if exists catalogue_bikes_bump on public.catalogue_bikes;
create trigger catalogue_bikes_bump after insert or update or delete on public.catalogue_bikes
  for each statement execute function public.catalogue_bump();

alter table public.ref_data        enable row level security;
alter table public.catalogue_bikes enable row level security;
alter table public.catalogue_parts enable row level security;
drop policy if exists "members only" on public.ref_data;
create policy "members only" on public.ref_data
  for all to authenticated using (public.is_member()) with check (public.is_member());
drop policy if exists "members only" on public.catalogue_bikes;
create policy "members only" on public.catalogue_bikes
  for all to authenticated using (public.is_member()) with check (public.is_member());
drop policy if exists "members only" on public.catalogue_parts;
create policy "members only" on public.catalogue_parts
  for all to authenticated using (public.is_member()) with check (public.is_member());
grant select, insert, update, delete on public.ref_data, public.catalogue_bikes, public.catalogue_parts to authenticated;
revoke all on public.ref_data, public.catalogue_bikes, public.catalogue_parts from anon;
-- ===================================================================
