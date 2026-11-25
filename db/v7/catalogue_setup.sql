-- Motoreez v7: move the 23 Nov catalogue table aside (kept as a backup), then the workshop team's setup
alter table if exists public.catalogue_parts rename to catalogue_parts_v6;
alter index if exists public.catalogue_parts_pkey rename to catalogue_parts_v6_pkey;
drop trigger if exists catalogue_parts_bump on public.catalogue_parts_v6;

-- Motoreez v7 · parts catalogue tables (25 Nov 2026)
-- Run once in the Supabase SQL editor. Safe to run again: everything is
-- "if not exists" / "drop policy if exists" and no data is deleted.
--
-- Tables:  catalogue_parts    one row per brand + part number
--          catalogue_fitment  one row per part x bike (make, model, version)
--          zana_products      one row per Zana product code + bike
--          zana_fitment       one row per Zana product code + bike x app bike
--          *_stage            plain-text landing tables for the CSV import
--
-- Access (mirrors the kv table): only signed-in members of this workshop
-- (public.is_member() = true) can read. Nobody can write from the app:
-- the data is loaded by the owner from the SQL editor / psql, which runs
-- as the service role and is not limited by row-level security.

-- public.is_member() already exists (the app calls it at sign-in). Stop here
-- with a clear message if it doesn't, rather than opening the tables up.
do $$ begin
  if to_regprocedure('public.is_member()') is null then
    raise exception 'public.is_member() not found: run the workshop setup (setup guide, step 2) first';
  end if;
end $$;

create extension if not exists pg_trgm;

-- ------------------------------------------------------------------ parts
create table if not exists public.catalogue_parts (
  brand                text not null,
  part_number          text not null,
  alt_part_numbers     text not null default '',
  name                 text not null default '',
  category             text not null default 'Unmapped',
  sub_category         text not null default '',
  source_category      text not null default '',
  source_sub_category  text not null default '',
  fits                 text not null default '',
  makes                text not null default '',
  models               text not null default '',
  bikes_count          integer not null default 0,
  uom                  text not null default 'piece',
  mrp_incl_gst         numeric(12,2),
  price_source         text not null default '',
  price_date           text not null default '',
  price_note           text not null default '',
  price_available      boolean not null default false,
  status               text not null default 'active',
  is_colour            boolean not null default false,
  colour               text not null default '',
  original_description text not null default '',
  search_text          text not null default '',
  updated_at           timestamptz not null default now(),
  primary key (brand, part_number)
);

create table if not exists public.catalogue_fitment (
  brand                text not null,
  part_number          text not null,
  alt_part_numbers     text not null default '',
  name                 text not null default '',
  category             text not null default '',
  sub_category         text not null default '',
  make                 text not null,
  model                text not null,
  version              text not null default '',
  engine_family        text not null default '',
  position             text not null default '',
  qty_per_bike         text not null default '',
  uom                  text not null default '',
  mrp_incl_gst         numeric(12,2),
  price_source         text not null default '',
  price_date           text not null default '',
  status               text not null default 'active',
  source               text not null default '',
  source_section       text not null default '',
  source_bike_name     text not null default '',
  source_ref           text not null default '',
  original_description text not null default '',
  primary key (brand, part_number, make, model, version),
  foreign key (brand, part_number) references public.catalogue_parts (brand, part_number) on delete cascade
);

-- ------------------------------------------------------------------ Zana
create table if not exists public.zana_products (
  code_clean          text not null,              -- 'ZI- 8204' -> 'ZI-8204'
  bike                text not null default '',   -- Zana's own model name; '' = universal
  zana_id             text not null default '',
  code_raw            text not null default '',
  name                text not null default '',
  category            text not null default '',
  sub_category        text not null default '',
  source_category     text not null default '',
  source_sub_category text not null default '',
  short_description   text not null default '',
  long_description    text not null default '',
  price_mrp_incl_gst  numeric(12,2),
  original_price      numeric(12,2),
  supplier_stock      integer,
  image_url           text not null default '',
  images              text not null default '',
  product_url         text not null default '',
  is_bike_specific    boolean not null default false,
  is_merch            boolean not null default false,
  is_active           boolean not null default true,
  zana_brand          text not null default '',
  fits                text not null default '',
  source_bike_name    text not null default '',
  search_text         text not null default '',
  updated_at          timestamptz not null default now(),
  primary key (code_clean, bike)
);

create table if not exists public.zana_fitment (
  code_clean       text not null,
  bike             text not null default '',
  zana_brand       text not null default '',
  make             text not null default '',
  model            text not null default '',
  version          text not null default '',
  year_from        text not null default '',
  year_to          text not null default '',
  matched          boolean not null default false,
  source_bike_name text not null default '',
  primary key (code_clean, bike, make, model),
  foreign key (code_clean, bike) references public.zana_products (code_clean, bike) on delete cascade
);

-- ------------------------------------------------------------------ staging (all text, for \copy / dashboard import)
create table if not exists public.catalogue_parts_stage (
  brand text, part_number text, alt_part_numbers text, name text, category text, sub_category text,
  source_category text, source_sub_category text, fits text, makes text, models text, bikes_count text,
  uom text, mrp_incl_gst text, price_source text, price_date text, price_note text, price_available text,
  status text, is_colour text, colour text, original_description text, search_text text);
create table if not exists public.catalogue_fitment_stage (
  brand text, part_number text, alt_part_numbers text, name text, category text, sub_category text,
  make text, model text, version text, engine_family text, position text, qty_per_bike text, uom text,
  mrp_incl_gst text, price_source text, price_date text, status text, source text, source_section text,
  source_bike_name text, source_ref text, original_description text);
create table if not exists public.zana_products_stage (
  code_clean text, bike text, zana_id text, code_raw text, name text, category text, sub_category text,
  source_category text, source_sub_category text, short_description text, long_description text,
  price_mrp_incl_gst text, original_price text, supplier_stock text, image_url text, images text,
  product_url text, is_bike_specific text, is_merch text, is_active text, zana_brand text, fits text,
  source_bike_name text, search_text text);
create table if not exists public.zana_fitment_stage (
  code_clean text, bike text, zana_brand text, make text, model text, version text,
  year_from text, year_to text, matched text, source_bike_name text);

-- ------------------------------------------------------------------ indexes
create index if not exists catalogue_parts_name_trgm   on public.catalogue_parts using gin (name gin_trgm_ops);
create index if not exists catalogue_parts_pn_trgm     on public.catalogue_parts using gin (part_number gin_trgm_ops);
create index if not exists catalogue_parts_alt_trgm    on public.catalogue_parts using gin (alt_part_numbers gin_trgm_ops);
create index if not exists catalogue_parts_desc_trgm   on public.catalogue_parts using gin (original_description gin_trgm_ops);
create index if not exists catalogue_parts_search_trgm on public.catalogue_parts using gin (search_text gin_trgm_ops);
create index if not exists catalogue_parts_cat         on public.catalogue_parts (category, sub_category);
create index if not exists catalogue_parts_name_order  on public.catalogue_parts (name, part_number);
create index if not exists catalogue_parts_brand       on public.catalogue_parts (brand);
create index if not exists catalogue_parts_pn_upper    on public.catalogue_parts (upper(part_number));
create index if not exists catalogue_fitment_bike      on public.catalogue_fitment (make, model, version);
create index if not exists catalogue_fitment_model     on public.catalogue_fitment (model);
create index if not exists catalogue_fitment_part      on public.catalogue_fitment (brand, part_number);
create index if not exists zana_products_search_trgm   on public.zana_products using gin (search_text gin_trgm_ops);
create index if not exists zana_products_name_trgm     on public.zana_products using gin (name gin_trgm_ops);
create index if not exists zana_products_cat           on public.zana_products (category, sub_category);
create index if not exists zana_fitment_bike           on public.zana_fitment (make, model);

-- ------------------------------------------------------------------ access
-- ------------------------------------------------------------------ access
alter table public.catalogue_parts         enable row level security;
alter table public.catalogue_fitment       enable row level security;
alter table public.zana_products           enable row level security;
alter table public.zana_fitment            enable row level security;
alter table public.catalogue_parts_stage   enable row level security;
alter table public.catalogue_fitment_stage enable row level security;
alter table public.zana_products_stage     enable row level security;
alter table public.zana_fitment_stage      enable row level security;

drop policy if exists "members read" on public.catalogue_parts;
drop policy if exists "members read" on public.catalogue_fitment;
drop policy if exists "members read" on public.zana_products;
drop policy if exists "members read" on public.zana_fitment;
create policy "members read" on public.catalogue_parts   for select to authenticated using (public.is_member());
create policy "members read" on public.catalogue_fitment for select to authenticated using (public.is_member());
create policy "members read" on public.zana_products     for select to authenticated using (public.is_member());
create policy "members read" on public.zana_fitment      for select to authenticated using (public.is_member());
-- no insert / update / delete policies: the app can only read these tables.
-- stage tables have RLS on and no policies at all: invisible to the app.

revoke all on public.catalogue_parts, public.catalogue_fitment, public.zana_products, public.zana_fitment from anon;
revoke insert, update, delete, truncate on public.catalogue_parts, public.catalogue_fitment, public.zana_products, public.zana_fitment from authenticated;
grant select on public.catalogue_parts, public.catalogue_fitment, public.zana_products, public.zana_fitment to authenticated;
revoke all on public.catalogue_parts_stage, public.catalogue_fitment_stage, public.zana_products_stage, public.zana_fitment_stage from anon, authenticated;
