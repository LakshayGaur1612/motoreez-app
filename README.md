# Motoreez Job Cards

The Motoreez workshop app: job cards, store, billing, ledgers, staff and job chat.

- `index.html`: the whole app
- `config.js`: which Supabase project the app talks to (URL and publishable key only)
- `setup.sql`: the database setup, already run once in Supabase
- `netlify.toml`: tells Netlify to serve the files as they are

Every push to `main` goes live on Netlify automatically. The workshop's data lives
in Supabase, never in this repository.
