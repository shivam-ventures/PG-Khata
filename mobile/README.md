# PG Khata — Flutter app

The Flutter client for PG Khata. Project-level documentation lives one level up:

- [`../README.md`](../README.md) — product overview and where the project stands
- [`../docs/architecture.md`](../docs/architecture.md) — this app's structure, state
  management, and the mock-repository-to-Supabase swap plan
- [`../docs/DECISIONS.md`](../docs/DECISIONS.md) — the running decisions log

## Running it

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
