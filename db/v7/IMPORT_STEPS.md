# Loading the v7 parts catalogue into Supabase

For Lakshay. The whole job takes about 15 minutes. It doesn't touch the workshop's own data (the `kv` table, job cards, the store). It only adds four new read-only tables.

## What's in this pack

| File | What it is |
|---|---|
| `catalogue_setup.sql` | Creates the 4 tables, their 4 landing ("stage") tables, search indexes and access rules |
| `catalogue_load.sql` | Moves rows from the stage tables into the real tables and prints counts |
| `csv/catalogue_parts_01.csv`, `_02.csv` | 111,693 parts (one row per brand + part number) |
| `csv/catalogue_fitment_01.csv` … `_03.csv` | 344,446 part × bike rows |
| `csv/zana_products_01.csv` | 1,266 Zana products |
| `csv/zana_fitment_01.csv` | 1,454 Zana product × app bike rows |
| `csv/MANIFEST.txt` | Row count and size of every file |

Every CSV is UTF-8 with a header row and is under 45 MB.

## Run order

1. **Set up the tables.** Open Supabase → SQL Editor → New query. Paste all of `catalogue_setup.sql` and click Run. If it stops with "public.is_member() not found", the workshop setup (setup guide, step 2) hasn't been run on this project. Fix that first.
2. **Load the CSVs into the stage tables.** Use option A or B below. Load each file into the stage table with the same name:
   - `catalogue_parts_*.csv` → `catalogue_parts_stage`
   - `catalogue_fitment_*.csv` → `catalogue_fitment_stage`
   - `zana_products_*.csv` → `zana_products_stage`
   - `zana_fitment_*.csv` → `zana_fitment_stage`
3. **Move the rows into the real tables.** In the SQL Editor, paste all of `catalogue_load.sql` and Run. It ends by printing four counts.
4. **Check the counts** (see the table below). If they match, run the commented `truncate … _stage` line at the end of `catalogue_load.sql` to empty the landing tables.
5. **Open the app.** Go to Store → Parts catalogue while signed in. The top line should say "Full catalogue (server)", with 111,693 parts and Spares | Zana tabs.

### Option A: psql (recommended, fastest)

Get the connection string from Project Settings → Database → Connection string (URI, "Session" pooler). Then, from the folder that holds `csv/`:

```bash
export DB='postgresql://postgres.<project-ref>:<db-password>@<host>:5432/postgres'
psql "$DB" -f catalogue_setup.sql
for f in csv/catalogue_parts_*.csv;   do psql "$DB" -c "\copy public.catalogue_parts_stage   from '$f' with (format csv, header true)"; done
for f in csv/catalogue_fitment_*.csv; do psql "$DB" -c "\copy public.catalogue_fitment_stage from '$f' with (format csv, header true)"; done
psql "$DB" -c "\copy public.zana_products_stage from 'csv/zana_products_01.csv' with (format csv, header true)"
psql "$DB" -c "\copy public.zana_fitment_stage  from 'csv/zana_fitment_01.csv'  with (format csv, header true)"
psql "$DB" -f catalogue_load.sql
```

Type the database password yourself. Don't paste it into chat or save it in a file in the repo.

### Option B: Supabase dashboard (no terminal)

1. Go to Table Editor, open `catalogue_parts_stage` and choose Insert → Import data from CSV.
2. Pick `catalogue_parts_01.csv`. Check that the columns line up by name, then import.
3. Repeat for `_02`, then for each of the other stage tables and their files.
4. Run `catalogue_load.sql` in the SQL Editor (step 3 above).

If the SQL Editor times out on the fitment insert, run the four `insert … ;` blocks of `catalogue_load.sql` one at a time. If one still times out, use option A for it.

## Counts to expect

| Table | Rows |
|---|---|
| catalogue_parts | 111,693 |
| catalogue_fitment | 344,446 |
| zana_products | 1,266 |
| zana_fitment | 1,454 |

Each stage table should hold the sum of its CSV files' rows from `MANIFEST.txt` before step 3. Check with:

```sql
select count(*) from public.catalogue_parts_stage;   -- 111,693
select count(*) from public.catalogue_fitment_stage; -- 344,446
```

## Running it again (new prices, a new brand)

You can run everything again safely:

- `catalogue_setup.sql` only creates what's missing. It never drops a table.
- `catalogue_load.sql` upserts:
  - The same brand + part number, or the same Zana code + bike, is updated in place.
  - A blank price in the new file never wipes a price that's already there.
- To reload from scratch, first empty the stage tables (`truncate … _stage`). Then repeat steps 2–4.
- Rows that were dropped from a newer file are **not** deleted automatically. To remove them, ask before deleting anything.

## Who can see and change it

- **Read:** only signed-in members of this workshop, checked with `public.is_member()`. That's the same check the app already uses for the `kv` table at sign-in.
- **Write:** nobody from the app. There are no insert, update or delete rules for the app's users. Only the SQL Editor or psql (owner / service role) can load or change the catalogue.
- **Stage tables:** have row-level security on and no read rule, so the app can't see them.
