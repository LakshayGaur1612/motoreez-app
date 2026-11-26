-- Motoreez v8 (26 Nov 2026) - one-time database changes.
-- Safe to run more than once. Run after the v7 catalogue_setup.sql.
-- 1. The accessories table (zana_products) gets the other makers.
-- 2. The reference-data table (ref_data) the app reads bike fluids, engine counts,
--    tyre sizes and the catalogue's filter lists from. Skip block 2 if ref_data
--    already exists (Lakshay's v7+ build created it).

-- ------------------------------------------------------------------ 1. accessories
alter table public.zana_products add column if not exists maker        text not null default 'Zana';
alter table public.zana_products add column if not exists product_line text not null default '';
alter table public.zana_products add column if not exists shop_links   text not null default '';
alter table public.zana_products add column if not exists variants     text not null default '';
alter table public.zana_products add column if not exists price_source text not null default '';
alter table public.zana_products add column if not exists fit_status   text not null default '';
alter table public.zana_products_stage add column if not exists maker text;
alter table public.zana_products_stage add column if not exists product_line text;
alter table public.zana_products_stage add column if not exists shop_links text;
alter table public.zana_products_stage add column if not exists variants text;
alter table public.zana_products_stage add column if not exists price_source text;
alter table public.zana_products_stage add column if not exists fit_status text;
-- Zana's own Z Pro range (ZP- codes) is a product line under Zana
update public.zana_products set product_line='Z Pro' where code_clean like 'ZP-%' and product_line='';
create index if not exists zana_products_maker on public.zana_products (maker, product_line);

