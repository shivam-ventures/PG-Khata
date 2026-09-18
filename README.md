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
| Flutter development environment | ⏳ Not yet set up on this machine — see below |
| Flutter app implementation | ⏳ Not started — was a Next.js/React implementation, discarded |
| Database — real schema, RLS, backend integration | ⏳ Deliberately not started |

**This repository previously contained a Next.js/React web implementation of Phase 0** (design tokens,
OTP auth, empty dashboards). That implementation has been **discarded** — the product's actual
requirement is a mobile app, not a web app — but nothing is lost: a full git snapshot exists before
the removal, and every piece of *product* work (decisions, design/README reconciliation, domain model
notes, the approved design itself) is preserved in this repo. See `docs/DECISIONS.md`'s 2026-09-18
entry for the full rationale.

## What's actually implemented in code right now

**Nothing yet.** The Flutter app hasn't been created — the Flutter SDK isn't installed on this
machine yet (see the environment status below). This section will be updated as real Dart code lands;
until then, don't trust any claim of "done" outside this table.

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

Checked on this machine (2026-09-18) — **nothing below has been installed automatically**; installs
happen only once explicitly authorized.

| Tool | Status | Needed for |
|---|---|---|
| Git | ✅ Installed (2.50.1) | Version control |
| Flutter SDK | ❌ Not installed | Everything — the app can't be created without it |
| Dart | ❌ Not installed (ships with the Flutter SDK) | Compiling/running the app |
| Homebrew | ❌ Not installed | The easiest install path for the tools below |
| Java/JDK | ❌ Not installed | Android builds (Gradle needs a JDK) |
| Xcode (full) | ❌ Not installed (only Command Line Tools) | iOS builds, iOS Simulator — **must be installed by you**, it needs an Apple ID sign-in via the App Store or developer.apple.com, which nobody but you should do |
| Android Studio | ❌ Not installed | Easiest way to manage the Android SDK/emulator (a command-line-only SDK setup is possible instead) |
| CocoaPods | ❌ Not installed | Linking native iOS dependencies in Flutter builds |
| VS Code | ❌ Not installed | Optional — any editor with the Flutter/Dart plugin works |

Once the Flutter SDK and platform tooling are in place, `mobile/` will hold the app — see
`docs/architecture.md` for its planned internal structure.

## Project structure

```
design/               The approved design handoff (screens, design system tokens) — source of truth
                       for UI/UX, translated into Flutter rather than copied as markup
docs/                  Decisions log, design/README reconciliation, domain model notes, architecture
supabase/schema.sql    Database schema + RLS policies from the pre-pivot plan — reflects an older
                       domain model (see the reconciliation doc); revisited deliberately once the
                       database phase starts, not reused as-is
mobile/                The Flutter app (created once the SDK is installed)
```

## Important product decisions

See [`docs/DECISIONS.md`](docs/DECISIONS.md) for the running log — including the 2026-09-18 platform
pivot to Flutter — and [`docs/design-readme-reconciliation.md`](docs/design-readme-reconciliation.md)
§6 for decisions raised by the design pass that are still open.
