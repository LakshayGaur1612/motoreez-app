-- Motoreez v9 · clean part numbers for the catalogue search (27 Nov 2026)
-- Run once in the Supabase SQL editor. Safe to run again.
-- Adds read-only helper columns the database keeps up to date by itself, and
-- their indexes. No row is changed or deleted.
--
--   catalogue_parts.pn_key   part number without hyphens, spaces or case   BK7-F6311-00 -> BK7F631100
--   catalogue_parts.pn_base  the same without an RE revision letter        574128/A     -> 574128
--   catalogue_parts.alt_key  old numbers, cleaned, between ; marks         DT151010     -> ;DT151010;
--   zana_products.code_key   accessory code, cleaned                       ZI- 8204     -> ZI8204

alter table public.catalogue_parts
  add column if not exists pn_key text
    generated always as (upper(regexp_replace(part_number, '[^A-Za-z0-9]', '', 'g'))) stored;
alter table public.catalogue_parts
  add column if not exists pn_base text
    generated always as (upper(regexp_replace(regexp_replace(part_number, '/\s*[A-Za-z]\s*$', ''), '[^A-Za-z0-9]', '', 'g'))) stored;
alter table public.catalogue_parts
  add column if not exists alt_key text
    generated always as (';' || upper(regexp_replace(regexp_replace(coalesce(alt_part_numbers, ''), '\s*[;|,]\s*', ';', 'g'), '[^A-Za-z0-9;]', '', 'g')) || ';') stored;
alter table public.zana_products
  add column if not exists code_key text
    generated always as (upper(regexp_replace(code_clean, '[^A-Za-z0-9]', '', 'g'))) stored;

create index if not exists catalogue_parts_pn_key   on public.catalogue_parts (pn_key text_pattern_ops);
create index if not exists catalogue_parts_pn_base  on public.catalogue_parts (pn_base);
create index if not exists catalogue_parts_alt_key  on public.catalogue_parts using gin (alt_key gin_trgm_ops);
create index if not exists zana_products_code_key   on public.zana_products (code_key text_pattern_ops);

-- the app reads these columns with the rest of the table (members only, as before)
grant select on public.catalogue_parts, public.zana_products to authenticated;

-- tell the server's API about the new columns
notify pgrst, 'reload schema';

-- check: each line should show a number above 0
select 'parts with a clean number' as what, count(*) from public.catalogue_parts where pn_key <> ''
union all select 'old numbers listed', count(*) from public.catalogue_parts where alt_key <> ';;'
union all select 'accessory codes', count(*) from public.zana_products where code_key <> '';
