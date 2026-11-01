# PG Khata — Flutter app

The Flutter client for PG Khata. Project-level documentation lives one level up:

- [`../README.md`](../README.md) — product overview and where the project stands
- [`../docs/architecture.md`](../docs/architecture.md) — this app's structure, state
  management, and the mock-repository-to-Supabase swap plan
- [`../docs/DECISIONS.md`](../docs/DECISIONS.md) — the running decisions log

## Running it

Needs a `.env` in this directory with `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the anon key is safe to
bundle — RLS is the real authorization boundary, not secrecy of this key). Never put the
`service_role` key or DB password here.

```
flutter pub get
flutter run
```

## Verifying a change

```
dart format lib/ test/
flutter analyze
flutter test
```
