# PG Khata

Rent, rooms and tenants, without the paper register. A mobile-first **Flutter** app for running
paying-guest (PG) accommodations, backed by a real **Supabase** project (Postgres with row-level
security, security-definer functions for every state-changing action, Edge Functions for privileged work).

Three roles use it:

| Role | What they do |
|---|---|
| **Owner** | Oversees a portfolio of PGs: properties, rooms, tenants, payments, complaints, reports, audit log, announcements |
| **Manager** | Runs one or more PGs day to day: collects rent, assigns beds, handles complaints, posts announcements |
| **Tenant** | Self-service: sees rent due, pays/confirms payments, reports issues, reads announcements |

**Status in one line:** the product is feature-complete for a V1 pilot and runs end to end against a real
backend, but it is **not ready for real customers yet**. A few features are simulated and some production
setup is outstanding. See [Before going live](#4-before-going-live) for the full list, starting with the
blockers.

---

## Contents

1. [Requirements](#1-requirements)
2. [What is implemented](#2-what-is-implemented)
3. [What is left](#3-what-is-left)
4. [Before going live](#4-before-going-live)
5. [Getting started (for developers)](#5-getting-started-for-developers)
6. [Project structure](#6-project-structure)
7. [Documentation index](#7-documentation-index)

---

## 1. Requirements

These come from the approved design handoff
([`design/design_handoff_pg_khata_app/README.md`](design/design_handoff_pg_khata_app/README.md)), the
product decisions log ([`docs/DECISIONS.md`](docs/DECISIONS.md)), and direct instructions during development.

### Product

- **Three roles** with role-aware navigation: Owner, Manager, Tenant. Owner and Manager can manage
  multiple properties.
- **Mobile-first**, card-based UI (no desktop tables). Light and dark themes. Design system "Modernist"
  (square corners, single red accent, Archivo type).
- **Sign-in by phone number + OTP.** No passwords.
- **Tenant onboarding, two paths:**
  - *Invite link*: a manager generates a bed-specific, expiring link; the tenant verifies by OTP and
    lands in an active tenancy.
  - *Self-registration*: a signed-out person picks a PG from a public listing, verifies by OTP, and waits
    in a "needs a bed" queue for staff to assign a bed and rent.
- **Properties, rooms, beds:** CRUD, with occupancy always derived from live tenancies (never a stored flag).
- **Tenants:** add, transfer between beds, give notice, move out. Bulk CSV import for properties and tenants.
- **Rent payments:**
  - Cash and digital methods.
  - **Cash confirm loop:** staff record a cash payment, the tenant confirms or disputes it, and only the
    Owner can resolve a dispute (with a required note).
  - Partial payments, idempotent retries, void with audit trail.
- **Rent generation:** a monthly job creates rent periods for every active tenancy; a new tenancy's first
  period is prorated by days remaining in the move-in month.
- **Complaints:** tenant reports, manager *delegates in one tap* (Self / Cleaner / Electrician / Plumber /
  Outside vendor), the ticket **auto-resolves after 3 days** unless the tenant reopens it. Server-side
  derived, not a client-side timer.
- **Move-out:** 15 days' notice. Shorter notice requires an explicit "forfeit the deposit" acknowledgment.
  Deposit settlement on move-out.
- **Reports** for the Owner: revenue, occupancy, complaint resolution.
- **Notifications inbox** for all roles, **audit log** for the Owner, **announcements** from Owner/Manager
  to tenants.
- **Settings:** language and notification preferences.
- **Identity decisions:** no Aadhaar e-KYC in V1 (plain ID photo with a manual "checked" flag instead; real
  Aadhaar is V2). A tenant's identity is separate from any one stay, so the same person can have tenancies
  with different owners. ID documents stay scoped to the tenancy they were uploaded for.

### Languages (explicit instruction)

- **Full-app localization, every screen.** English is the default; **Telugu** is the second language.
  The user picks it in Settings and the choice is stored on their profile.

### Engineering

- Flutter (Dart) client; Supabase backend; Riverpod state; `go_router` navigation.
- Authorization lives in the database (RLS + security-definer RPCs), not in the client. The client is
  untrusted.
- Every state-changing action is a single database function that also writes its notification and audit
  entry as a side effect. The client never writes the audit log directly.

### Out of scope on purpose (decided, not forgotten)

- WhatsApp Q&A assistant and inbound WhatsApp actions (reply-to-complain, reply-to-confirm). Cut from the MVP.
- `RoleSwitcher` (a design-prototype aid) and a Super Admin UI.
- Aadhaar e-KYC. Deferred to V2.

---

## 2. What is implemented

Everything below talks to the real Supabase project. No mock repository is wired into the running app
(`MockXRepository` classes remain only for isolated widget tests).

| Area | Implemented |
|---|---|
| **Auth** | Phone + OTP via Supabase Auth, `profiles` table for role/identity, role-aware routing, sign-out, preferred language |
| **Properties** (Owner) | Portfolio CRUD, occupancy metrics, manager assignment (pick existing or invite new), bulk CSV import |
| **Rooms** | Owner (floor-grouped, property switcher) and Manager (flat list) views; room and bed CRUD; "Assign existing" and "Invite via link" on vacant beds |
| **Tenants** | Owner (portfolio) and Manager (per-PG) rosters; add/edit, transfer, give notice, cancel notice, move out, deposit settlement, "self-registered, needs a bed" queue, bulk CSV import |
| **Payments** | Record (cash/UPI/bank), tenant confirm/dispute, Owner dispute resolution, void, partial payments, per-period ledger, idempotency keys on every write |
| **Complaints** | Report, delegate, resolve, reopen, 3-day auto-resolve, category and severity, preferred visit time; Tenant, Manager and Owner views |
| **Onboarding** | Invite-link join and direct self-registration, both through phone OTP; first rent period prorated |
| **Rent generation** | `pg_cron` job `generate-rent-periods-monthly` (`5 0 1 * *`, UTC) plus immediate first-period generation on every new tenancy; notice-period tenants are still billed until they leave |
| **Notifications** | Written by every payment/complaint/tenancy RPC; inbox with unread badge and mark-as-read for all roles |
| **Audit log** | Owner-only, filterable history of recorded mutations |
| **Announcements** | Owner and Manager authoring; tenant-facing display |
| **Reports** (Owner) | Revenue, occupancy, complaint-resolution computed live (see the trend-chart caveat in section 4) |
| **Dashboards** | Role-specific home screens: Owner overview, Manager "Today", Tenant home with pay-rent card |
| **Settings** | Language selector (English / Telugu), notification preferences (complaints, announcements) |
| **Localization** | English and Telugu: bottom navigation, More menu, and every screen and dialog for Payments, Complaints, Properties, Rooms, Tenants, Reports, Notifications, Audit Log, Announcements and Settings. About 430 strings per language, in sync (ICU plurals included) |
| **Design system** | StatusChip, StatCard, EmptyState, ErrorState, skeleton loaders, buttons, text field, dialog, nav bar, list cards. Light and dark `ThemeData` built from the approved tokens |

**Backend** ([`supabase/`](supabase/)): 39 migrations, 19 tables (`organizations`, `profiles`, `properties`,
`property_managers`, `rooms`, `beds`, `tenancies`, `tenant_profiles`, `tenant_invite_links`,
`tenant_signup_interests`, `rent_periods`, `payments`, `payment_allocations`, `complaints`,
`complaint_events`, `notifications`, `announcements`, `audit_log`, `id_documents`), RLS on every table,
security-definer RPCs for all mutations, public listing views for the signed-out join flow, and three Edge
Functions (`add-tenant`, `add-manager`, `resolve-invite`) for work that needs the Admin API.

**Quality gates at the time of this commit:**

- `flutter test`: **78 / 78 passing**
- `flutter analyze`: **0 errors, 0 warnings**, 13 info-level lints (null-aware-element suggestions, the
  deprecated `Radio` API, and the deprecated `anonKey` name)
- English and Telugu string files verified key-for-key identical
- Flows exercised live in a browser against the real backend as all three roles, in both languages

---

## 3. What is left

### Features not built

| Item | State |
|---|---|
| **Online rent payment (Razorpay or similar)** | The tenant Pay Rent flow is a **simulation**. See blocker #1 in section 4 |
| **ID document upload** | The `id_documents` table and a storage bucket exist, but there is no upload or review UI |
| **Real document scan (OCR)** | The "scan a document" button in the add-tenant dialogs returns **fake sample people**. See blocker #3 |
| **Rent reminders and push notifications** | Notifications exist only as an in-app inbox. Nothing is delivered outside the app (no push, SMS or WhatsApp) |
| **WhatsApp features** | Outbound reminders, manager daily digest, one-tap receipts, owner weekly digest. All planned, none built |
| **Historical occupancy** | No snapshot storage, so the Reports trend chart is illustrative |
| **Bed hold / book-ahead reservations** | Designed in the decisions log, deliberately not built |
| **More languages** | Only English and Telugu. The profile column currently restricts values to `en` / `te` |
| **Offline support** | None. Every action needs connectivity |

### Localization gaps

- **Month and weekday names are always English.** `DateLabelFormatter` and the month abbreviations in
  `reports_providers.dart` are hardcoded. Fixing it means switching to locale-aware `intl` `DateFormat`.
- **Two onboarding screens are still English only:** `join_invite_screen.dart` and `self_register_screen.dart`.
- **Backend-generated text is English only:** error messages from the database, notification titles and
  bodies, and audit-log action descriptions.
- **Telugu was machine-drafted.** Have a native speaker review it before showing it to customers.
- Free text a user types (names, announcement text, complaint titles) is of course shown as written.

### Cleanup

- Unused: `shared/widgets/placeholder_screen.dart`, `not_built_yet.dart`.
- Replace deprecated APIs: `anonKey` to `publishableKey` in `main.dart`; `Radio` to `RadioGroup` (two dialogs).
- No automated tests exist for the database layer (RLS policies and RPCs). See section 4.

---

## 4. Before going live

Ordered by severity. Items 1 to 5 are launch blockers.

### Blockers

1. **"Pay Rent" does not move any money.**
   The tenant's UPI/card flow waits 1.6 seconds and then calls `record_self_payment`, which inserts the
   payment as **`paid` immediately**. The amount must match what is owed, but nothing verifies a real
   transaction. Any tenant can mark their own rent as paid without paying.
   *Fix one of:* integrate a gateway (Razorpay is anticipated in `.env.example`) and mark the payment paid
   only from a verified server-side webhook; or remove the button and make tenants rely on the cash
   confirm loop until the gateway ships.

2. **OTP is test-only.**
   Sign-in works only because `supabase/config.toml` defines fixed test OTPs (code `123456`) for three demo
   numbers. A real number gets no SMS. Configure a real provider (Twilio block exists but is disabled;
   `.env.example` mentions MSG91), remove `[auth.sms.test_otp]`, and delete the demo users from production.
   Indian SMS delivery generally requires **DLT registration** of your sender ID and message templates,
   which can take days to weeks, so start early.

3. **The document-scan button shows fake data.**
   `shared/widgets/document_scan.dart` "reads" a photo by returning one of five hardcoded people (for
   example "Amit Verma"). A real manager would get a stranger's name pre-filled into a tenant record.
   Remove the button or wire a real vision/OCR service before launch.

4. **The Reports occupancy trend chart is fake.**
   `reports_providers.dart` hardcodes `[78, 80, 83, 85, 84, 86]`. Hide the chart, or add a monthly
   occupancy snapshot table (a `pg_cron` job that records it) and chart that.

5. **There is no production environment yet.**
   The app currently points at a single Supabase project that is also the dev project and holds demo data.
   For launch: create a separate production project, apply all 39 migrations, deploy the three Edge
   Functions, confirm `pg_cron` is enabled and the monthly job is scheduled, and keep dev and prod
   credentials strictly separate.

### Security and correctness

- **Run a dedicated security review of the database.** All authorization lives in RLS policies and
  security-definer functions, and there are **no automated tests** for them. A manual pre-launch audit on
  2026-09-25 found six real bugs or gaps (migrations 33 to 38: partial-payment status, self-payment amount
  validation, notice-period billing, hard-delete vs archive, a single source for the notice threshold, the
  ID-document storage bucket), which shows the process works but also that more may remain. Pay particular attention
  to the paths reachable **without signing in**: `public_property_listings`, `resolve-invite`, and
  `self_register_tenant`.
- Add SQL-level tests (for example pgTAP) that assert each role can and cannot read and write each table.
- Check rate limits and abuse controls on OTP sending and the public self-registration endpoint
  (`config.toml` sets 30 SMS per hour project-wide; check the setting on the hosted project, which is what
  actually applies).
- Confirm that Edge Function secrets and the service-role key are only ever set as server-side secrets.
  The client must only ever hold the anon (publishable) key.
- Confirm RLS is still enabled on every table after any future migration.

### App store readiness

- **App identity:** the Android label is `pg_khata`, the `pubspec.yaml` description is the Flutter
  template default, and iOS shows "Pg Khata". Set a proper name, description, launcher icon and splash.
- **Bundle/application id** is `com.pgkhata.pg_khata`. Decide the final id **before** the first Play Store
  upload, because it cannot be changed afterwards.
- **Android release signing:** copy `mobile/android/key.properties.example` to `key.properties`, create a
  keystore, and **back the keystore up somewhere safe**. Without `key.properties` the build silently falls
  back to debug signing. Consider Play App Signing.
- **iOS** needs Xcode, an Apple Developer account, and CocoaPods (which needs a newer Ruby than macOS ships).
  iOS has not been verified. Development and testing so far have been on Android and web.
- Version is `1.0.0+1`. Bump the build number for every upload.
- Prepare store listings, screenshots, and the Play "Data safety" and App Store privacy declarations.

### Legal and privacy

You store phone numbers, names, rent history and (eventually) ID photos for people who are not your
customers (tenants). Talk to a lawyer about the following. This README is not legal advice.

- A **privacy policy** and **terms of service**, linked in the app and the store listings.
- **India's DPDP Act, 2023** obligations for personal data: consent, purpose limitation, retention, and
  breach handling.
- **Account and data deletion:** a user-facing way to delete an account and its data (app stores require
  it). Today the database archives rather than deletes (by design, migration 36), so decide what deletion
  means for financial history and the audit log.
- A retention policy for ID documents, once upload exists.

### Operations

- **Backups and uptime:** check what your Supabase plan gives you. Free-tier projects can pause when
  inactive and do not include point-in-time recovery. A paid plan is the normal choice for production data.
  Test a restore at least once.
- **Monitoring:** there is no crash reporting or analytics (no Sentry, Crashlytics, or similar). Add crash
  reporting before launch, and decide on analytics and how consent is handled.
- **Time zones:** `pg_cron` runs in UTC, so the monthly rent job fires at about 05:35 IST on the 1st. Confirm
  that matches how due dates and "overdue" are shown to users.
- **Support path:** decide how users reach you, and how a manager recovers if they lose their phone number.
- **Data migration:** owners moving from a paper register will want a way to import history. Today there is
  CSV import for properties and tenants only, not past payments.
- **Pilot first:** run with one or two friendly PGs and real cash flow for a billing cycle before opening up.
  The decisions log notes the real unknown is whether owners will actually replace their register.

### Housekeeping before wider sharing

- Pay Rent and document scan should be fixed or hidden *before* anyone outside the team uses the app,
  even for a pilot, because both can silently produce wrong records.
- Telugu review (see section 3), and complete the two onboarding screens.
- Clear out the 13 analyzer lints and the deprecated APIs so a future Flutter upgrade does not break things.

---

## 5. Getting started (for developers)

**Prerequisites:** Flutter 3.47.x (stable) with Dart 3.13, Supabase CLI 2.x, and for Android: JDK 17 and
Android SDK 34/36. iOS additionally needs Xcode and CocoaPods.

```bash
git clone git@github.com:shivam-ventures/PG-Khata.git
cd PG-Khata
git checkout Phase-0-1-development
cd mobile
```

**Configure the backend connection.** Create `mobile/.env` (it is gitignored) with:

```
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_ANON_KEY=<the project's anon / publishable key>
```

Get these from the Supabase dashboard under Project Settings, then API. Ask the project owner for access
to the current dev project. **Never** put the `service_role` key or the database password in this file or
anywhere in the repo.

```bash
flutter pub get      # also generates the localization classes from the .arb files
flutter run          # pick an Android device, or add: -d chrome
```

**Demo accounts** (dev project only; OTP is always `123456`):

| Role | Phone | Name |
|---|---|---|
| Owner | `9876543210` | Anita Sharma |
| Manager | `9876500000` | Ramesh Kumar |
| Tenant | `9822233445` | Rahul Sharma |

**Before pushing a change:**

```bash
dart format lib/ test/
flutter analyze
flutter test
```

**Backend work** (needs access to the Supabase project):

```bash
cd supabase
supabase link --project-ref <ref>
supabase db push          # applies migrations/ in order
```

Never edit an applied migration. Add a new numbered one. `supabase/seed-users.mjs` creates the demo users
and must not be run against production.

**Localization:** strings live in `mobile/lib/l10n/app_en.arb` (the template) and `app_te.arb`. Add every
new string to both. The generated `app_localizations*.dart` files are gitignored and rebuilt by
`flutter pub get`. In widgets, use `AppLocalizations.of(context)`.

---

## 6. Project structure

```
design/                 Approved design handoff (screens, tokens). Source of truth for UI,
                        translated into Flutter rather than copied as markup
docs/                   Decisions log, architecture, domain model, design/README reconciliation
supabase/migrations/    The real applied schema: tables, RLS, RPCs, views, pg_cron schedule
supabase/functions/     Edge Functions: add-tenant, add-manager, resolve-invite
supabase/config.toml    Local/linked project config (includes the dev-only test OTPs)
mobile/lib/
  app/                  App root, theme wiring
  core/                 Routing, theme tokens, errors, session, Supabase client, shared utils
  features/<name>/      One folder per feature, each with domain / data / application / presentation
                        (announcements, audit_log, auth, complaints, dashboard, notifications,
                         onboarding, payments, properties, reports, rooms, tenants)
  shared/widgets/       Reusable design-system widgets
  l10n/                 English and Telugu .arb files
mobile/test/            Unit and widget tests
```

Pattern worth knowing: each feature has a repository interface with a Supabase implementation (used by the
app) and a mock implementation (used only in tests). Data stays in raw domain form, and text is formatted
at render time so it can be localized.

---

## 7. Documentation index

| Doc | What it covers |
|---|---|
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Running log of product and engineering decisions, and why |
| [`docs/architecture.md`](docs/architecture.md) | App structure, state management, repository pattern |
| [`docs/backend-domain-model.md`](docs/backend-domain-model.md) | Backend schema design and RPC contracts |
| [`docs/backend-ui-data-audit.md`](docs/backend-ui-data-audit.md) | Which UI field maps to which backend data |
| [`docs/domain-model-notes.md`](docs/domain-model-notes.md) | Domain model notes |
| [`docs/design-readme-reconciliation.md`](docs/design-readme-reconciliation.md) | Design vs. README gap analysis |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Design tokens and component notes |
| [`mobile/README.md`](mobile/README.md) | Short Flutter app quick reference |

Note: `docs/DECISIONS.md` is thorough up to the Phase 1 work (September 18). Later decisions, such as
the Supabase backend, the pre-launch audit findings, and localization, are recorded in migration comments
and in this README rather than the log. Worth back-filling.
