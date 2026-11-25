-- Motoreez v7 · move the imported CSV rows from the *_stage tables into the
-- real catalogue tables. Run in the SQL editor AFTER all CSV chunks are in
-- the stage tables. Safe to run again: rows are upserted (same brand + part
-- number / same Zana code + bike updates in place), nothing is duplicated.

begin;

insert into public.catalogue_parts as t (brand, part_number, alt_part_numbers, name, category, sub_category,
  source_category, source_sub_category, fits, makes, models, bikes_count, uom, mrp_incl_gst, price_source,
  price_date, price_note, price_available, status, is_colour, colour, original_description, search_text, updated_at)
select distinct on (brand, part_number)
  brand, part_number, coalesce(alt_part_numbers,''), coalesce(name,''), coalesce(nullif(category,''),'Unmapped'),
  coalesce(sub_category,''), coalesce(source_category,''), coalesce(source_sub_category,''), coalesce(fits,''),
  coalesce(makes,''), coalesce(models,''), coalesce(nullif(bikes_count,'')::int,0), coalesce(nullif(uom,''),'piece'),
  nullif(mrp_incl_gst,'')::numeric, coalesce(price_source,''), coalesce(price_date,''), coalesce(price_note,''),
  lower(coalesce(price_available,'false'))='true', coalesce(nullif(status,''),'active'),
  lower(coalesce(is_colour,'false'))='true', coalesce(colour,''), coalesce(original_description,''),
  coalesce(search_text,''), now()
from public.catalogue_parts_stage
where coalesce(brand,'')<>'' and coalesce(part_number,'')<>''
on conflict (brand, part_number) do update set
  alt_part_numbers=excluded.alt_part_numbers, name=excluded.name, category=excluded.category,
  sub_category=excluded.sub_category, source_category=excluded.source_category,
  source_sub_category=excluded.source_sub_category, fits=excluded.fits, makes=excluded.makes,
  models=excluded.models, bikes_count=excluded.bikes_count, uom=excluded.uom,
  mrp_incl_gst=coalesce(excluded.mrp_incl_gst, t.mrp_incl_gst),
  price_source=case when excluded.mrp_incl_gst is null then t.price_source else excluded.price_source end,
  price_date=case when excluded.mrp_incl_gst is null then t.price_date else excluded.price_date end,
  price_note=case when excluded.mrp_incl_gst is null then t.price_note else excluded.price_note end,
  price_available=excluded.price_available or t.price_available, status=excluded.status,
  is_colour=excluded.is_colour, colour=excluded.colour, original_description=excluded.original_description,
  search_text=excluded.search_text, updated_at=now();

insert into public.catalogue_fitment as t (brand, part_number, alt_part_numbers, name, category, sub_category,
  make, model, version, engine_family, position, qty_per_bike, uom, mrp_incl_gst, price_source, price_date,
  status, source, source_section, source_bike_name, source_ref, original_description)
select distinct on (s.brand, s.part_number, s.make, s.model, coalesce(s.version,''))
  s.brand, s.part_number, coalesce(s.alt_part_numbers,''), coalesce(s.name,''), coalesce(s.category,''),
  coalesce(s.sub_category,''), s.make, s.model, coalesce(s.version,''), coalesce(s.engine_family,''),
  coalesce(s.position,''), coalesce(s.qty_per_bike,''), coalesce(s.uom,''), nullif(s.mrp_incl_gst,'')::numeric,
  coalesce(s.price_source,''), coalesce(s.price_date,''), coalesce(nullif(s.status,''),'active'),
  coalesce(s.source,''), coalesce(s.source_section,''), coalesce(s.source_bike_name,''), coalesce(s.source_ref,''),
  coalesce(s.original_description,'')
from public.catalogue_fitment_stage s
join public.catalogue_parts p on p.brand=s.brand and p.part_number=s.part_number
where coalesce(s.make,'')<>'' and coalesce(s.model,'')<>''
on conflict (brand, part_number, make, model, version) do update set
  alt_part_numbers=excluded.alt_part_numbers, name=excluded.name, category=excluded.category,
  sub_category=excluded.sub_category, engine_family=excluded.engine_family, position=excluded.position,
  qty_per_bike=excluded.qty_per_bike, uom=excluded.uom, mrp_incl_gst=coalesce(excluded.mrp_incl_gst,t.mrp_incl_gst),
  price_source=excluded.price_source, price_date=excluded.price_date, status=excluded.status, source=excluded.source,
  source_section=excluded.source_section, source_bike_name=excluded.source_bike_name, source_ref=excluded.source_ref,
  original_description=excluded.original_description;

insert into public.zana_products as t (code_clean, bike, zana_id, code_raw, name, category, sub_category,
  source_category, source_sub_category, short_description, long_description, price_mrp_incl_gst, original_price,
  supplier_stock, image_url, images, product_url, is_bike_specific, is_merch, is_active, zana_brand, fits,
  source_bike_name, search_text, updated_at)
select distinct on (code_clean, coalesce(bike,''))
  code_clean, coalesce(bike,''), coalesce(zana_id,''), coalesce(code_raw,''), coalesce(name,''), coalesce(category,''),
  coalesce(sub_category,''), coalesce(source_category,''), coalesce(source_sub_category,''),
  coalesce(short_description,''), coalesce(long_description,''), nullif(price_mrp_incl_gst,'')::numeric,
  nullif(original_price,'')::numeric, nullif(supplier_stock,'')::numeric::int, coalesce(image_url,''),
  coalesce(images,''), coalesce(product_url,''), lower(coalesce(is_bike_specific,'false'))='true',
  lower(coalesce(is_merch,'false'))='true', lower(coalesce(is_active,'true'))='true', coalesce(zana_brand,''),
  coalesce(fits,''), coalesce(source_bike_name,''), coalesce(search_text,''), now()
from public.zana_products_stage
where coalesce(code_clean,'')<>''
on conflict (code_clean, bike) do update set
  zana_id=excluded.zana_id, code_raw=excluded.code_raw, name=excluded.name, category=excluded.category,
  sub_category=excluded.sub_category, source_category=excluded.source_category,
  source_sub_category=excluded.source_sub_category, short_description=excluded.short_description,
  long_description=excluded.long_description, price_mrp_incl_gst=excluded.price_mrp_incl_gst,
  original_price=excluded.original_price, supplier_stock=excluded.supplier_stock, image_url=excluded.image_url,
  images=excluded.images, product_url=excluded.product_url, is_bike_specific=excluded.is_bike_specific,
  is_merch=excluded.is_merch, is_active=excluded.is_active, zana_brand=excluded.zana_brand, fits=excluded.fits,
  source_bike_name=excluded.source_bike_name, search_text=excluded.search_text, updated_at=now();

insert into public.zana_fitment as t (code_clean, bike, zana_brand, make, model, version, year_from, year_to, matched, source_bike_name)
select distinct on (s.code_clean, coalesce(s.bike,''), coalesce(s.make,''), coalesce(s.model,''))
  s.code_clean, coalesce(s.bike,''), coalesce(s.zana_brand,''), coalesce(s.make,''), coalesce(s.model,''),
  coalesce(s.version,''), coalesce(s.year_from,''), coalesce(s.year_to,''), lower(coalesce(s.matched,'false'))='true',
  coalesce(s.source_bike_name,'')
from public.zana_fitment_stage s
join public.zana_products p on p.code_clean=s.code_clean and p.bike=coalesce(s.bike,'')
on conflict (code_clean, bike, make, model) do update set
  zana_brand=excluded.zana_brand, version=excluded.version, year_from=excluded.year_from, year_to=excluded.year_to,
  matched=excluded.matched, source_bike_name=excluded.source_bike_name;

commit;

-- empty the landing tables once the counts below look right
-- truncate public.catalogue_parts_stage, public.catalogue_fitment_stage, public.zana_products_stage, public.zana_fitment_stage;

-- counts to compare with IMPORT_STEPS.md
select 'catalogue_parts' t, count(*) from public.catalogue_parts
union all select 'catalogue_fitment', count(*) from public.catalogue_fitment
union all select 'zana_products', count(*) from public.zana_products
union all select 'zana_fitment', count(*) from public.zana_fitment;
