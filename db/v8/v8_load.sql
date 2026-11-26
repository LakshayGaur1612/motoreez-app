-- Motoreez v8 - move the new accessories from the stage tables into the real ones.
-- Load csv/accessories_products.csv into zana_products_stage and
-- csv/accessories_fitment.csv into zana_fitment_stage first (same as v7).
insert into public.zana_products as t (code_clean, bike, zana_id, code_raw, name, category, sub_category,
  source_category, source_sub_category, short_description, long_description, price_mrp_incl_gst, original_price,
  supplier_stock, image_url, images, product_url, is_bike_specific, is_merch, is_active, zana_brand, fits,
  source_bike_name, search_text, maker, product_line, shop_links, variants, price_source, fit_status)
select code_clean, coalesce(bike,''), coalesce(zana_id,''), coalesce(code_raw,''), coalesce(name,''), coalesce(category,''),
  coalesce(sub_category,''), coalesce(source_category,''), coalesce(source_sub_category,''), coalesce(short_description,''),
  coalesce(long_description,''), nullif(price_mrp_incl_gst,'')::numeric, nullif(original_price,'')::numeric,
  nullif(supplier_stock,'')::integer, coalesce(image_url,''), coalesce(images,''), coalesce(product_url,''),
  lower(coalesce(is_bike_specific,'false'))='true', lower(coalesce(is_merch,'false'))='true', lower(coalesce(is_active,'true'))='true',
  coalesce(zana_brand,''), coalesce(fits,''), coalesce(source_bike_name,''), coalesce(search_text,''),
  coalesce(nullif(maker,''),'Zana'), coalesce(product_line,''), coalesce(shop_links,''), coalesce(variants,''), coalesce(price_source,''), coalesce(fit_status,'')
from public.zana_products_stage
where code_clean is not null and code_clean<>''
on conflict (code_clean, bike) do update set
  name=excluded.name, category=excluded.category, sub_category=excluded.sub_category, source_category=excluded.source_category,
  short_description=excluded.short_description, price_mrp_incl_gst=excluded.price_mrp_incl_gst, image_url=excluded.image_url,
  images=excluded.images, product_url=excluded.product_url, is_bike_specific=excluded.is_bike_specific, is_merch=excluded.is_merch,
  is_active=excluded.is_active, zana_brand=excluded.zana_brand, fits=excluded.fits, source_bike_name=excluded.source_bike_name,
  search_text=excluded.search_text, maker=excluded.maker, product_line=excluded.product_line, shop_links=excluded.shop_links,
  variants=excluded.variants, price_source=excluded.price_source, fit_status=excluded.fit_status, updated_at=now();

insert into public.zana_fitment as t (code_clean, bike, zana_brand, make, model, version, year_from, year_to, matched, source_bike_name)
select s.code_clean, coalesce(s.bike,''), coalesce(s.zana_brand,''), coalesce(s.make,''), coalesce(s.model,''),
  coalesce(s.version,''), coalesce(s.year_from,''), coalesce(s.year_to,''), lower(coalesce(s.matched,'false'))='true', coalesce(s.source_bike_name,'')
from public.zana_fitment_stage s
join public.zana_products p on p.code_clean=s.code_clean and p.bike=coalesce(s.bike,'')
on conflict (code_clean, bike, make, model) do update set
  zana_brand=excluded.zana_brand, version=excluded.version, year_from=excluded.year_from, year_to=excluded.year_to,
  matched=excluded.matched, source_bike_name=excluded.source_bike_name;

-- counts by maker (expect Zana 1,266 - Race Dynamics 1,506 - BMC 460 - Red Rooster 201 - Maddog 62 - AEW 50 - Powerage 46)
select maker, count(*) from public.zana_products group by maker order by 2 desc;
select 'zana_fitment', count(*) from public.zana_fitment;
-- then empty the landing tables:
-- truncate public.zana_products_stage, public.zana_fitment_stage;
