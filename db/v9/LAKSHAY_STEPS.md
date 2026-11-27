# v9 – one database step

1. Open Supabase → project MTRZ → SQL Editor → New query.
2. Paste the whole of `db/v9/part_numbers.sql` and press Run. It takes up to a minute.
3. The last result shows three lines (parts with a clean number, old numbers listed, accessory codes), each above 0.

That's it. Nothing is deleted or changed; the database adds clean copies of the part numbers and keeps them up to date itself. Until this is run, the app searches catalogue part numbers the old way.
