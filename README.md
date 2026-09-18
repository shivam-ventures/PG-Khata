# PG Khata

Rent, rooms and tenants — without the register. A mobile-first **Flutter** app for managing
paying-guest (PG) accommodations, with three roles: **Owner** (portfolio-level oversight across
properties), **Manager** (day-to-day operations at one or more PGs), and **Tenant** (self-service for
the resident).

## Where the product stands

| Phase | Status |
|---|---|
| Design — full-app UI design for Owner/Manager/Tenant | ✅ Complete (approved, 18 screens) |
| Platform decision — mobile-first, Flutter/Dart | ✅ Decided (2026-09-18) |
| Flutter development environment | ✅ Set up (2026-09-18) — Flutter, JDK, Android SDK, Supabase CLI |
| Phase 0 — Flutter foundation | ✅ Implemented (2026-09-18) — see below |
| Phase 1 — Properties/Rooms/Tenants (Owner + Manager) | ✅ Implemented (2026-09-18) — see below |
| Phase 2+ — Tenant self-serve onboarding, Payments, Complaints | ⏳ Not started |
| Database — real schema, RLS, backend integration | ⏳ Deliberately not started (Phase 6) |

**This repository previously contained a Next.js/React web implementation of Phase 0** (design tokens,
OTP auth, empty dashboards). That implementation has been **discarded** — the product's actual
requirement is a mobile app, not a web app — but nothing is lost: a full git snapshot exists before
the removal, and every piece of *product* work (decisions, design/README reconciliation, domain model
notes, the approved design itself) is preserved in this repo. See `docs/DECISIONS.md`'s 2026-09-18
entry for the full rationale.

## What's actually implemented in code right now

**Phase 0 (Flutter foundation)** — in `mobile/`:

- Flutter project scaffold (Android + iOS targets), `flutter analyze` clean, 29 tests passing
  (`flutter test`)
- Design system translated into a Flutter `ThemeData`/`ColorScheme` from the approved screens'
  actual tokens (`tokens-extra.css` — see `docs/architecture.md`), light + dark
- `go_router` role-aware navigation: phone/OTP login, then role-specific bottom-nav shells for
  Owner/Manager/Tenant, each branch either a real screen or a labeled placeholder for a later phase
- Riverpod state management throughout; a `Repository` interface + mock implementation per feature
  (`AuthRepository`/`MockAuthRepository`, `DashboardRepository`/`MockDashboardRepository`), so a
  Supabase-backed implementation is a Phase 6 swap behind the same interface
- Mock phone/OTP auth (send, verify, invalid-code, resend cooldown, logout, session state) — see
  `MockAuthRepository`'s doc comment for how it resolves a role without a real backend yet
- Owner Dashboard, Manager Today, and Tenant Home fully implemented against realistic mock data
  ported from the approved screens' own mock data, each with loading/empty/error states
- Shared components: StatusChip, StatCard, EmptyState, ErrorState, skeleton loaders, buttons, text
  field, dialog, quick-action tiles, bottom nav, CtaCard, ListRowCard

**Phase 1 (Properties/Rooms/Tenants)** — also in `mobile/`, same mock-repository pattern:

- Owner Properties: portfolio list with occupancy bars, add/edit property
- Rooms: Owner (floor-grouped, property switcher, Add Room) and Manager (flat list for their PG) —
  vacant beds offer "Assign existing"/"Invite via link" (Manager) or "+ Add tenant" (Owner)
- Tenants: Owner (whole-portfolio roster, search + property filter) and Manager (one-PG roster,
  pre-fillable from a Rooms link or a quick action) — add, assign a self-registered pending tenant to
  a bed, and move-out, all staff-initiated (the tenant-*requested* self-registration path stays
  excluded, per the open product decision in `docs/design-readme-reconciliation.md` §6.3)
- `flutter analyze` clean, 41 tests passing (`flutter test`)

Two real bugs were found and fixed by actually running the app in a browser rather than trusting the
widget tree alone (see `docs/DECISIONS.md`'s Phase 1 entry): a `Center`/`Align` shrink-wrap collapsing
every screen to its bottom-nav height on web, and a button-in-a-`Row` starving its sibling of width via
an inherited infinite minimum-width theme default.

**Not yet real:** any backend call (still 100% mock data), CocoaPods (blocked on this machine's Ruby
version — see the environment table), and the Android debug build hasn't been verified end-to-end on
this machine — Gradle's first-time setup (distribution + AGP + Kotlin compiler + per-arch engine
jars) needs several GB this machine doesn't reliably have free right now; `flutter analyze` and
`flutter test` are both clean, and the app has been verified running correctly via `flutter build web`
in a browser — this remaining gap is specifically the `flutter build apk` step. See
`docs/DECISIONS.md`'s 2026-09-18 Phase 0 entry.

## Completed design scope (approved, not yet implemented)

A full 18-screen design handoff exists for every role — now stored in this repo at
`design/design_handoff_pg_khata_app/` (previously only an external zip file). See that folder's own
`README.md` for the screen-by-screen index, and `docs/architecture.md` for how it translates into a
Flutter `ThemeData` and widget structure.

**Owner flows (designed):** Dashboard (attention items, quick actions, property list), Properties
(list + add/edit), Rooms (floor-grouped room/bed occupancy), Tenants (roster, search/filter, move-out,
assign self-registered tenants), Payments (portfolio rent ledger, record-payment), Reports (revenue by
property, occupancy trend, property comparison).

**Manager flows (designed):** Today (mini-stats, quick actions, rent-to-collect + open-complaints
tasks), Collect Rent (cash/UPI/bank recording, cash goes to "awaiting confirmation"), Rooms
(occupancy + "assign existing" or "invite via link" for vacant beds), Tenants (add/assign/move-out),
Complaints (delegate-and-done model, see below), More (overflow menu to Tenants/Complaints/Settings).

**Tenant flows (designed):** Home (rent status, pending-cash confirmation banner, PG announcements,
quick actions, last payment, complaint status), Payments (rent card, confirm/dispute a cash payment,
history), Complaints (report with category/severity/preferred time, status with a "not fixed yet?"
reopen link).

**Shared:** Settings (profile, notification preferences, language), a portfolio/PG switcher for
multi-property Owners and Managers.

### Complaints — redesigned model (most important flow to get right)

`Reported → Delegated → Resolved` (or `Reopened`). A Manager's only required action is
**"Delegate & done"** — pick who's handling it (Self/Cleaner/Electrician/Plumber/Outside vendor) + an
optional note. A delegated ticket **auto-resolves after 3 days** unless the tenant says it's still not
fixed. Full detail and the open product questions this raises: `docs/design-readme-reconciliation.md`.

### Payments — cash confirm/dispute loop

A Manager recording a cash payment sets it to **"Awaiting confirmation"**; the Tenant then confirms it
or disputes it. Digital payments (UPI/Bank Transfer) go straight to Paid.

### Onboarding — self-registration + invite links (not yet decided)

The design adds self-serve signup and bed-specific invite links — a real trust-boundary change from
Owner-provisioned-only accounts. **Flagged as a decision required, not yet adopted** — see the
reconciliation doc.

## Known design/product gaps

Full detail in [`docs/design-readme-reconciliation.md`](docs/design-readme-reconciliation.md) — what's
in the README but not designed, what's designed but wasn't in the original plan, and the specific
product decisions still needed. This document is platform-agnostic and was unaffected by the Flutter
pivot.

Domain entities and relationships discovered while studying the design (not a database schema — that
comes later, deliberately) are in [`docs/domain-model-notes.md`](docs/domain-model-notes.md).

Flutter architecture, state-management choice, and the offline/notifications assessments are in
[`docs/architecture.md`](docs/architecture.md).

## Development environment status

Checked on this machine (2026-09-18).

| Tool | Status | Needed for |
|---|---|---|
| Git | ✅ Installed (2.50.1) | Version control |
| Flutter SDK | ✅ Installed (3.47.4 stable) | Everything |
| Dart | ✅ Installed (3.13.3, ships with Flutter) | Compiling/running the app |
| Java/JDK | ✅ Installed (Temurin 17.0.20.1) | Android builds (Gradle needs a JDK) |
| Android SDK | ✅ Installed (platform-tools, build-tools 34.0.0, platforms 34 & 36, licenses accepted) | Android builds |
| Xcode (full) | ❌ Not installed (only Command Line Tools) | iOS builds, iOS Simulator — **must be installed by you**, it needs an Apple ID sign-in via the App Store or developer.apple.com, which nobody but you should do |
| CocoaPods | ❌ Blocked — needs Ruby ≥3.0, this machine's system Ruby is 2.6.10 | Linking native iOS dependencies — not actionable until Xcode exists anyway |
| Supabase CLI | ✅ Installed (2.117.0) | Phase 6 backend work |
| Android emulator | ⏭️ Skipped by design — use a physical Android device (USB debugging) instead, to conserve this machine's limited disk space |
| `flutter analyze` / `flutter test` | ✅ Clean — 0 issues, 29/29 tests passing | Verifying the code itself |
| `flutter build apk --debug` | ⚠️ Not yet verified — see below | Verifying the full Android toolchain end-to-end |

**On the unverified Android build:** Gradle's first-time setup for this project (the Gradle
distribution, Android Gradle Plugin, Kotlin compiler, and per-architecture Flutter engine jars) needs
several GB of headroom, and this machine's disk ran out of free space twice while attempting it — see
`docs/DECISIONS.md`'s 2026-09-18 Phase 0 entry. The code itself is verified via `flutter analyze` and
`flutter test`; only this one build-verification step is pending more free disk space.

## Project structure

```
design/               The approved design handoff (screens, design system tokens) — source of truth
                       for UI/UX, translated into Flutter rather than copied as markup
docs/                  Decisions log, design/README reconciliation, domain model notes, architecture
supabase/schema.sql    Database schema + RLS policies from the pre-pivot plan — reflects an older
                       domain model (see the reconciliation doc); revisited deliberately once the
                       database phase starts, not reused as-is
mobile/                The Flutter app — Phase 0 foundation implemented, see docs/architecture.md
```

## Important product decisions

See [`docs/DECISIONS.md`](docs/DECISIONS.md) for the running log — including the 2026-09-18 platform
pivot to Flutter — and [`docs/design-readme-reconciliation.md`](docs/design-readme-reconciliation.md)
§6 for decisions raised by the design pass that are still open.
