# Motoreez v8 (26 Nov 2026) — steps for Lakshay

v8 is built on your "HTML_for_Jatin.html". Your sign-in, `ref_data`, server-only catalogue, attendance sync and v2 preview are all kept as they were. Following your note in section 9 of the file header, no data is pasted into the HTML; everything new goes into the database. Section 11 of the header lists what v8 adds.

About 20 minutes. The workshop's own data (`kv`, job cards, Store) is not touched.

## What's in this pack

| File | What it is |
|---|---|
| `Motoreez-2026-11-26-v8.html` | The app. Deploy it as `index.html` on Netlify, as before |
| `db/v8/v8_setup.sql` | Adds 6 columns to `zana_products` (+ stage) and creates `ref_data` if it doesn't exist |
| `db/v8/v8_load.sql` | Moves the new accessories from the stage tables into `zana_products` / `zana_fitment`, then prints counts |
| `db/v8/csv/accessories_products.csv` | 2,325 accessories from 6 makers (Race Dynamics, BMC, Red Rooster, Maddog, AEW, Powerage) |
| `db/v8/csv/accessories_fitment.csv` | 2,409 accessory × bike rows |
| `seed/bike_fluids.json`, `seed/bike_engine.json` | Approved oil / fork oil / brake fluid figures (415 bikes) and engine counts (633). Read by **Load starting data** |
| `seed/bike_tyres.json` | Approved front / rear tyre sizes (385 bike versions). Read by **Load v8 data** |
| `seed/catalogue_meta.json` | Catalogue filter lists, now with the accessory makers (`zana.makers`, `zana.lines`). Read by **Load v8 data** |

## Run order

1. **Back up first.** Supabase → Database → Backups, or at least export `zana_products` and `ref_data`.
2. **Run the setup.** SQL Editor → paste all of `v8_setup.sql` → Run.
   - Block 1 adds `maker`, `product_line`, `shop_links`, `variants`, `price_source`, `fit_status` to `zana_products` and its stage table. Existing Zana rows get `maker='Zana'`, and ZP- codes get `product_line='Z Pro'`.
   - Block 2 creates `ref_data` (key, ver, data jsonb) with a trigger that bumps `ver` on every write, plus member read/insert/update policies. **If your `ref_data` already exists with a different shape, skip block 2.** The app needs `key`, `ver` (changes on every update), and `data`, and the signed-in owner must be able to insert/upsert (`Prefer: resolution=merge-duplicates`).
3. **Load the accessories into the stage tables.** Use the same method as v7. With psql:
   ```bash
   psql "$DB" -c "truncate public.zana_products_stage, public.zana_fitment_stage"
   psql "$DB" -c "\copy public.zana_products_stage (code_clean,bike,zana_id,code_raw,name,category,sub_category,source_category,source_sub_category,short_description,long_description,price_mrp_incl_gst,original_price,supplier_stock,image_url,images,product_url,is_bike_specific,is_merch,is_active,zana_brand,fits,source_bike_name,search_text,maker,product_line,shop_links,variants,price_source,fit_status) from 'csv/accessories_products.csv' with (format csv, header true)"
   psql "$DB" -c "\copy public.zana_fitment_stage from 'csv/accessories_fitment.csv' with (format csv, header true)"
   ```
   In the dashboard: Table Editor → `zana_products_stage` → Import CSV. The columns match by name.
4. **Move them in.** Run `v8_load.sql`. Expected counts:

   | maker | rows |
   |---|---|
   | Race Dynamics | 1,506 |
   | Zana | 1,266 |
   | BMC | 460 |
   | Red Rooster | 201 |
   | Maddog | 62 |
   | AEW | 50 |
   | Powerage | 46 |
   | **zana_fitment** | 1,454 Zana + 2,409 new = **3,863** |

   Then run the commented `truncate … _stage` line.
5. **Deploy.** Put `Motoreez-2026-11-26-v8.html` as `index.html`, and the four JSON files in a `seed/` folder next to it, e.g. `https://motoreez.netlify.app/seed/bike_tyres.json`.
6. **Load the reference data.** Sign in as Kunal or Jatin (or the developer login) → Settings → Reference data.
   - If **Load starting data** is showing, tap it. It loads fluids and engine counts.
   - Tap **Load v8 data**. It loads tyre sizes and the new catalogue filter lists.
   - The card should then show 415 / 633 / 385 bikes and "3,591 from 7 makers".
7. **Check in the app.**
   - Catalogue → Accessories shows 3,591, with 8 maker chips.
   - Race Dynamics shows Fuel X / Powertronic chips.
   - Picking a bike also lists "Fits any bike — universal".
   - New job card for a Yamaha FZ-S Fi Hybrid → Tyres → Both offers only 100/80-17 front and 140/60-17 rear.

## Good to know

- **Falling back on an old schema.** If the v8 columns aren't there yet, the app falls back to the v7 columns, so the Accessories tab keeps working (Zana only). An unknown column (`42703`) no longer marks the catalogue as "missing".
- **What happens without step 6.** The app runs, but oil quantities, cylinder / injector / tappet counts and tyre sizes are blank. That's the same as your file with an empty `ref_data`.
- **New data on job cards** (inside the `kv` job JSON, no schema change):
  - `ownParts`, `pickNeed`, `tyrePos`, `reqQty`
  - `planSkip`: labour removed on the estimate, which `ensureReasonLines()` won't put back
  - `intakePending.edits`: estimate edits made before the card was complete
- **Labour Rates.** "Performance Air Filter Cleaning Labour" (₹500 + GST) is priced from `LABOUR_HEADS` until someone adds it to Labour Rates.
- **Store load.** Jatin imports his stock from Settings → Import → Inventory, with "includes GST" and "is today's count" selected. Nothing for you to do there.
- **Tests run** on desktop and phone sizes with a local PostgREST stand-in:
  - intake (reasons, picks, tyres, dents, extra bend, estimate editing carried onto the card)
  - Store import of the 1,041-row file
  - Accessories (makers, lines, Z Pro, universal, details, ✕ clear, old-schema fallback)
  - Earlier test suites: only the checks for behaviour v8 deliberately changed now fail (pre-picked OEM, the old reason tiles, "Zana accessories" naming).
