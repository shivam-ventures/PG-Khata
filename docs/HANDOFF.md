# PG Khata — Session Handoff

**Purpose:** a complete brief so a fresh Claude Code session (on any machine) can continue building PG Khata
without having seen the original conversation. Written 2026-11-04 from the full transcript of the original
session (Sep 14 → Nov 4, 2026, roughly 85 user messages across about 7 context compactions) plus a re-check of
the code.

**Read this first, then:** `README.md` (product status, requirements, launch checklist), `docs/DECISIONS.md`
(decisions up to Sep 18), `docs/architecture.md`, `docs/backend-domain-model.md`.
Where this file and the code disagree, **the code wins**. Verify before relying on anything here.

---

## 0. Start here (first 15 minutes)

1. **Get credentials from Shivam out-of-band.** They are NOT in the repo and must never be pasted into chat or
   committed. You need `mobile/.env` containing `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the anon key is safe to
   ship in the app; RLS is the real boundary). For backend work you additionally need the Supabase CLI logged in
   and `supabase link`ed to the project, plus the service-role key in a gitignored `.env.local` (only for the
   `supabase/seed-users.mjs` script and cleanup scripts). Ask Shivam for the project ref; it is the subdomain of
   `SUPABASE_URL`.
2. `cd mobile && flutter pub get` (this also generates `lib/l10n/app_localizations*.dart`, which are gitignored).
3. `flutter analyze` (expect 0 errors/warnings and 13 info lints), `flutter test` (expect 78/78).
4. Run: `.claude/launch.json` defines a `mobile` server (`flutter run -d web-server --web-port=8765`), or
   `flutter run -d chrome`. Log in with a demo account (section 9).
5. Read section 11 (known blockers) before building anything that touches payments, SMS or documents.
6. **Do not commit or push unless Shivam asks.** See section 1.

---

## 1. The person and how to work with them

- **Shivam**, founder (has a co-founder who now has repo access). Non-native English, writes in casual
  English/Hinglish with frequent typos ("implemeted", "penidng"). Interpret intent, do not mirror the typos.
- Building PG Khata as a **startup product**, first market **Hyderabad** (hence Telugu). Uses a MacBook Air; the
  original machine was **disk-space constrained** (often 0.5 to 2 GB free).
- **Working style they have rewarded:**
  - Doing the work *and* verifying it by actually running the app, not just `flutter analyze` / `flutter test`.
    Live browser testing found real bugs that static checks missed (they said "well done" to this approach).
  - Honest scope disclosure. When a task turned out much bigger than it sounded, the user preferred being told and
    then choosing, not silent shortcuts or silent scope-cuts.
  - "Implement everything professionally as a senior SDE": real implementations, no stubs passed off as done.
  - Strict audits ("try to break it, don't praise it").
- **Standing rules:**
  - Early on they said "write the code, don't commit anything". They later committed and pushed themselves, and on
    2026-11-01 asked for a commit + push. **Default: do not commit/push unless explicitly asked.**
  - Never ask the user to paste secrets in chat. (They did paste real keys on 2026-09-22; see section 12.)
  - For genuine business-policy ambiguity, ask a short structured question (they answer well to option lists).
    Example: "prorate by days remaining" was chosen this way.
  - Clean up any real test data you create in the live Supabase project.
- They ask conceptual questions mid-stream ("what is localization?", "is this how big apps do it?"). Answer briefly
  and plainly, then continue.

---

## 2. Product in one paragraph

Mobile-first Flutter app for managing paying-guest (PG) accommodation in India. Three roles: **Owner** (portfolio
of PGs), **Manager** (day-to-day at one or more PGs), **Tenant** (resident self-service). Phone + OTP login, no
passwords. Rent ledger with a cash confirm/dispute loop, complaints with delegate-and-auto-resolve, tenant
onboarding by invite link or self-registration, move-out with a notice period and deposit settlement,
announcements, notifications, audit log, reports. Backend is Supabase (Postgres + RLS + security-definer RPCs +
Edge Functions + pg_cron). UI languages: English (default) and Telugu.

---

## 3. History of the whole session (chronological)

Dates are from transcript timestamps (UTC).

### Sep 14 — Analysis of the original project
- First message: analyze the folder, what phases are done/left, acting as Staff Engineer + Product Designer + PM +
  Founder. The repo at that point was a **Next.js/TypeScript web app** plus a design handoff and docs.
- Decisions already in `docs/DECISIONS.md` from this period: skip Aadhaar e-KYC (use plain ID photo + manual check),
  WhatsApp digest for Managers, tenant onboarding in two paths, cross-owner discovery + identity/tenancy split
  (a person's identity is separate from a stay), WhatsApp Q&A bot cut from MVP.

### Sep 18 — Pivot to Flutter, environment, Phase 0 and 1
- User supplied the design zip ("PG Khata product design.zip", 18 HTML screens) and asked to reconcile the design
  with the README.
- User asked why a mobile app was not using a mobile language. After a React Native (Expo) vs Flutter comparison
  (the assistant first leaned Expo for code reuse and because no native toolchain was installed), **the user decided
  to restart in Flutter** and discard the Next.js web code. This is a final decision.
- Installed the toolchain on the user's Mac: Flutter, JDK 17 (Temurin), Android SDK (platform-tools, build-tools
  34, platforms 34/36), Supabase CLI. Instruction: do not break the system, keep it universal for future app
  projects. iOS is not set up (needs full Xcode + Apple ID + CocoaPods with newer Ruby). Disk space was a recurring
  constraint; the user also asked about moving tools/projects to an external SSD.
- **Phase 0** (foundation): a 35-section spec from the user. Riverpod, go_router, repository pattern with mock
  repositories, design tokens, role-aware navigation, shared widgets. Backend explicitly NOT touched yet.
- **Phase 1** (Properties / Rooms / Tenants) implemented against mocks.
- Live testing found 3 real bugs (AppScaffold shrink-wrap, StatCard overflow, button infinite min-width).
- GitHub: user wanted terminal access without tokens; a PAT push failed (403), so **SSH key auth** was set up for
  the account `shivam-ventures`. Remote: `git@github.com:shivam-ventures/PG-Khata.git`.

### Sep 19–20 — Phases 2 to 5 (all mocked) and extra features
- Phase 2 tenant onboarding (invite-link join: phone OTP → confirm name → done). Phase 3 payments, Phase 5
  complaints. Phase 4 (reminders / WhatsApp) deliberately put on hold: "ignore WhatsApp for now, we have to think
  about costing too."
- Then the user asked for: **online rent payment, reports, bulk import** (CSV import for Owner and Manager, plus a
  single-record "add from an image/form" option). Built as mocks; image scan was simulated.

### Sep 20–21 — Extreme UX audit and remediation
- User ordered a 35-section "break it" UX/UI audit. Delivered as a published Artifact ("Pre-Backend UX Audit").
- User's key product correction: *if a tenant pays online via the owner's UPI/QR, it should be marked paid
  automatically, not by a manager.* This led to the **payment trust model** (section 6.3).
- All 19 audit findings (P0 to P3) fixed, plus 9 bonus bugs, published as "Remediation Audit". Then a further round:
  Property vs Rooms/Payments data drift fixed via `PropertyMetrics`, plus StatCard grid overflow recurrences.
- User asked "UI completely ready end to end?" then committed and pushed the code themselves (Sep 21).

### Sep 21–22 — Backend design and Supabase setup
- User requested a production backend/database architecture. The assistant asked three questions; answers shaped
  the model: many-to-many (a manager can manage many properties, a property can have many managers), cross-owner
  tenant discovery, and what "dispute" means (see decisions).
- User floated a **PG marketplace** (tenants browsing PGs). Agreed direction: later, as a **separate web app on the
  same backend** (real vacancy data is the advantage). Not started.
- Supabase project created by the user; DB password reset; CLI access token generated. No Docker on the machine, so
  the hosted project is the dev database (`supabase db push --linked`), not a local stack.
- Migrations 1 to 24 built and applied: schema, RLS, RPCs, views, grants, and a series of fixes.
- Repositories swapped from mock to Supabase feature by feature: Auth, Properties, Rooms, Tenants + Onboarding,
  Payments, Complaints. Edge Functions `add-tenant`, `add-manager`, `resolve-invite` deployed.

### Sep 23 — Backlog of nine items (user's list)
1. Manager property scoping, 2. Owner Complaints screen, 3. dispute resolution UI, 4. tenant self-registration with
two paths (invite link + direct), 5. Aadhaar cost question (answered: V2), 6. notifications + audit log,
7. real manager assignment in Add/Edit PG, 8. real cron for rent generation + joining date + **prorate first month
by days remaining** (user's choice), 9. real SMS later ("when we are closing V1").
All implemented and verified live. Migrations 25 to 29.

### Sep 24 — Status review, settings, announcements, deposit, language
- Full "scoped vs implemented vs pending" review, README rewrite.
- User items: Settings with language (English default, **Telugu** needed since expansion is mainly in Hyderabad);
  complete Announcements UI + backend; explain RoleSwitcher (answer: design prototype aid, never ship); deposit
  settlement + move-out flow with **15 days' notice minimum, otherwise no deposit return, keep the rule easy to
  change**; no Super Admin UI; opinion on "building as an entity" (answer: don't add; use floor labels).
- Short-notice behaviour (user's choice): *reject, but allow proceeding after an explicit acknowledgment that the
  deposit is forfeited.*
- i18n scope (user's choice): **"Full app, every screen, right now."**
- Migrations 30 to 32 (announcements; move-out notice + deposit; profile preferences).

### Sep 25 — Pre-launch audit and localization
- A pre-launch audit found 6 backend bugs/gaps, fixed in migrations 33 to 38 (plus a follow-up fix in 39).
- Provider-layer restructuring so dashboards carry raw data and format at render time (needed for i18n).
- Localized: bottom nav, then all remaining screens. About 430 strings per language.

### Nov 1 — README, commit, push
- Rewrote the README; committed everything as `pg khata book initial phase` (commit `53bb7fe`); pushed to
  `origin/Phase-0-1-development`. The repo turned out to be **public** (see section 12).

### Nov 4 — This handoff (user is moving to another laptop as primary work desk).

---

## 4. Scope and requirements

Sources: `design/design_handoff_pg_khata_app/README.md`, `docs/DECISIONS.md`, and the user's instructions above.

**Roles & navigation.** Owner: Overview, PGs, Tenants, More (Payments, Reports, Complaints, Audit log,
Announcements). Manager: Today, Payments, Rooms, More (Tenants, Complaints, Announcements). Tenant: Home, Rent,
Complaints, Profile. Managers with several PGs switch with a PG context bar; the whole Manager side scopes to the
selected PG.

**Functional requirements (all user-driven or from the approved design):**
- Phone + OTP auth. No passwords.
- Properties / rooms / beds CRUD; occupancy always derived from live tenancies.
- Tenants: add, transfer, give notice, cancel notice, move out, mark deposit returned; CSV bulk import (Owner and
  Manager); "add from a photographed form/ID" option.
- Rent: monthly generation per tenancy, first period prorated by days remaining, partial payments, idempotent
  writes, cash confirm/dispute loop, void/correct, Owner-only dispute resolution.
- Complaints: report → delegate → resolved/reopened; auto-resolve 3 days after delegation unless reopened; derived
  server-side.
- Onboarding: invite link (bed-specific, expiring) and direct self-registration into a "needs a bed" queue.
- Reports (Owner), notifications inbox, audit log (Owner), announcements (Owner and Manager author, tenants read).
- Settings: language, notification preferences (rent reminders are always on by design).
- Localization: English + Telugu, every screen.

**Explicitly out of scope / deferred:** Aadhaar e-KYC (V2); real SMS (before V1 close); WhatsApp features
(cost); Super Admin UI; RoleSwitcher; Building as an entity; marketplace (separate future web app).

---

## 5. Architecture and conventions

**Stack:** Flutter 3.47.x / Dart 3.13, flutter_riverpod 3.4.x, go_router 18, supabase_flutter 2.10, flutter_dotenv,
google_fonts (Manrope headings, Inter body), csv, image_picker, file_picker, url_launcher, uuid, intl +
flutter_localizations. Supabase: Postgres 17, RLS, pg_cron, Edge Functions (Deno).

**Layout:** `mobile/lib/features/<feature>/{domain,data,application,presentation}`; shared code in `core/` and
`shared/widgets/`. Features: announcements, audit_log, auth, complaints, dashboard, notifications, onboarding,
payments, properties, reports, rooms, tenants.

**Repository pattern.** Each feature has an `abstract interface class XRepository`, a `SupabaseXRepository` (used by
the app) and a `MockXRepository` (tests only). A single `Provider<XRepository>` is the override point. Mutations are
free functions in `*_providers.dart` that call the repository and invalidate dependent providers. Errors are a typed
`Result<T>` (Ok/Err) with a **sealed** `AppFailure`, so all `AppFailure` subtypes must live in
`core/errors/app_failure.dart`. `ResultX.when` comes from `core/errors/result.dart` (a frequently forgotten import).

**Data/format rule (important for i18n).** Domain and provider layers carry **raw data** (enums, ints, DateTimes).
Formatting and localization happen **at render time** in widgets with `AppLocalizations.of(context)`. Do not bake
display strings into data classes. (Dashboards originally violated this; fixed.)

**Non-breaking migration pattern for labels.** Enums keep a legacy unlocalized `.label` (commented "Unlocalized,
kept only for call sites not yet migrated; prefer `labelFor`") and gain `labelFor(AppLocalizations l10n)`.
`RelativeTimeFormatter.agoFor/openFor(l10n, …)` and `GreetingFormatter.greetingFor(l10n, …)` follow the same idea.

**Authorization lives in the database.** RLS on all 19 tables. Cross-table checks go through `security definer
stable` helpers (`is_owner_of_org`, `is_manager_of_property`, `is_staff_for_property`, `tenant_has_current_property`,
`tenant_owns_*`, …) to avoid RLS recursion. Every state change is a security-definer RPC that also writes its
notification and audit entry. The client never writes `audit_log`.

**Design system.** The code uses the approved screens' `tokens-extra.css` layer: **indigo accent, Manrope + Inter,
radii 8/12/20, light and dark**. (The base "Modernist" tokens in the design README, red accent and square corners,
are superseded; `docs/DESIGN_SYSTEM.md` is also stale: it describes the discarded Tailwind setup.)

**Locale.** `localeProvider` derives from the signed-in user's `preferredLanguage` (default `en` before login), not
separate local state. Stored in `profiles.preferred_language` (`en` or `te`).

**Phone format.** `profiles.phone` is bare 10 digits everywhere; `auth.users.phone` is E.164 (+91…). A recurring bug
class was code copying E.164 into `profiles.phone`.

---

## 6. What is implemented

### 6.1 Backend (`supabase/`)

39 migrations (all applied to the linked dev project), 19 tables, 3 Edge Functions.

| # | Migration (purpose) |
|---|---|
| 1–8 | extensions; identity & orgs; properties/rooms/beds; tenancies & invites; payments; complaints; documents/notifications/audit; metrics views |
| 9–11 | RPCs: payments, complaints, tenancy |
| 12 | RLS policies |
| 13–20 | grants & fixes: service-role grants, occupancy statuses, notice-period metrics, RLS recursion, function grants, view security_invoker, revoke anon table grants |
| 21–24 | invite join phone format; invite token (`gen_random_uuid`); tenant→properties policy and recursion fix |
| 25–26 | prorated first rent period; **pg_cron** monthly rent generation (`5 0 1 * *` UTC) |
| 27 | notifications (written by every mutating RPC) |
| 28 | `complete_invite_join` smallint cast fix |
| 29 | tenant self-registration (public listing views, `self_register_tenant`, `pending` queue) |
| 30 | announcements |
| 31 | move-out notice + deposit settlement; `evaluate_move_out_notice`; **pg_cron** daily `finalize_due_move_outs` (`10 0 * * *`) |
| 32 | profile preferences (language, notification toggles) |
| 33–38 | pre-launch audit fixes: partial-payment status; self-payment amount validation; bill notice-period tenants; archive-not-delete; single source for notice threshold (`minimum_notice_days()`); ID-document storage bucket |
| 39 | rent-period status uses latest amount |

Key RPCs: `record_payment` (staff, always `awaiting_confirmation`), `record_self_payment` (tenant, settles `paid`),
`confirm_payment`, `dispute_payment`, `resolve_dispute` (Owner only, note required), `void_payment`,
`report_complaint`, `delegate_complaint`, `resolve_complaint`, `reopen_complaint`, `complaint_effective_status`,
`create_invite_link`, `complete_invite_join`, `self_register_tenant`, `assign_pending_tenant`,
`assign_tenant_to_bed`, `transfer_tenancy`, `request_move_out`, `cancel_move_out_notice`, `move_out_tenant`,
`mark_deposit_returned`, `finalize_due_move_outs`, `generate_rent_periods` (service-role/cron only),
`create_announcement`, `notify_user`, `notify_staff_for_property`.

Edge Functions (need Admin API): `add-tenant`, `add-manager`, `resolve-invite`. Deployment status on any new
project must be verified.

### 6.2 App features (all wired to Supabase)

Auth + Settings (language, notification toggles); Properties (CRUD, manager assignment, CSV import); Rooms (Owner
floor-grouped, Manager flat; invite via link); Tenants (Owner/Manager rosters, add/edit, notice, move-out, deposit,
pending queue, CSV import); Payments (record, confirm/dispute, resolve, void, partials, ledger, tenant Pay Rent);
Complaints (Tenant/Manager/Owner views); Onboarding (invite link + self-registration); Dashboards (Owner, Manager
Today, Tenant Home); Reports; Notifications; Audit log; Announcements; bottom navigation per role.

### 6.3 Payment trust model (decision, still in force)
- Staff-recorded payments (any method, including UPI) always land on **awaiting confirmation**; the tenant confirms
  or disputes; only the Owner can resolve a dispute (conflict-of-interest reasoning), with a required note.
- A tenant paying through the app settles instantly. **Currently simulated; see blocker 1.**
- Amount-mismatch confirmation exists in the Collect Rent/Record Payment dialogs. Voiding restores the owed amount.
- `record_self_payment` enforces amount == remaining balance (migration 34).

### 6.4 Localization
`mobile/l10n.yaml`, `lib/l10n/app_en.arb` (template) and `app_te.arb`, about 430 keys each, kept key-for-key
identical. ICU plurals used (Telugu uses one/other). Covered: login/OTP, Settings, bottom nav, More menu, all
dashboards, Payments, Complaints, Properties, Rooms, Tenants, Reports, Notifications, Audit log, Announcements,
shared widgets (error state "Try again", document scan sheet, list-row tooltip, dashboard header tooltip).
Workflow used: Python helper scripts merging new keys into both ARBs (`json.load` with `OrderedDict`,
`ensure_ascii=False`, indent 2) rather than hand-editing. Reuse existing keys when text is identical.
**Intentionally not localized:** user-typed data (names, announcement/notification text, floor names, assignee
names), DB error messages, audit action text, mock seed data.

### 6.5 Quality state
`flutter test` 78/78. `flutter analyze` 0 errors/warnings, 13 info lints (`use_null_aware_elements`, deprecated
`Radio.groupValue/onChanged`, deprecated `anonKey`). No DB-level tests exist.

---

## 7. What is pending

**Features**
- Real online payment gateway (Razorpay anticipated) with server-side verified webhook.
- ID document upload + staff review UI (table and storage bucket exist, no UI).
- Real document scan/OCR (currently fake).
- Rent reminders and any push/SMS/WhatsApp delivery (only an in-app inbox exists); WhatsApp digest, receipts,
  owner weekly digest (planned, cost-gated).
- Historical occupancy snapshots (so the Reports trend chart can be real).
- Real SMS OTP provider.
- Book-ahead/hold reservations (designed, not built); "browse and request a bed" marketplace flow (not built;
  self-registration instead puts the person in the "needs a bed" queue).
- More languages (column check currently allows only `en`/`te`).
- Offline support (none).

**Localization gaps**
- `DateLabelFormatter` and `_monthAbbrev` in `reports_providers.dart` always output English month/weekday names.
- `join_invite_screen.dart` and `self_register_screen.dart` are not localized.
- Backend-generated strings (DB errors, notification title/body, audit action text) are English only.
- Telugu strings are machine-drafted; need native review.

**Cleanup:** unused `shared/widgets/placeholder_screen.dart` and `not_built_yet.dart`; deprecated APIs (`anonKey` →
`publishableKey`, `Radio` → `RadioGroup`); `docs/DECISIONS.md` has no entries after Sep 18 (back-fill: Supabase
backend, audits, deposit/notice policy, i18n); `docs/DESIGN_SYSTEM.md` stale.

**Known deferred-on-purpose from the remediation audit:** CSV import has no deposit column; Tenant Home's manager
contact is deliberately minimal.

---

## 8. Business rules to preserve

- **Move-out notice:** 15 days minimum (`minimum_notice_days()` single source of truth, migration 37; the Flutter
  dialog's `_advisoryMinimumNoticeDays = 15` is advisory only, the server decides). Less than 15 days: allowed only
  with an explicit "forfeit the deposit" acknowledgment; deposit then `forfeited`. The user said this rule **may
  change**, so keep it in one place.
- **Deposit settlement states:** `pending` / `forfeited` / `returned`. Staff can mark returned.
- **Notice-period tenants are still billed** until they leave (migration 35).
- **First rent period is prorated** by days remaining in the move-in month, generated immediately at tenancy
  creation; later periods by cron on the 1st.
- **Complaint auto-resolve:** 3 days after delegation (`auto_resolve_days`), derived in SQL, never a client timer.
- **Archive, don't delete** (migration 36): financial history and audit trail must survive.
- Owners and Managers see only their own organization's / assigned properties' data; tenants see only their own.
- ID documents are scoped per tenancy, not per person (privacy line across owners).

---

## 9. Environment, running, and verifying

**Demo accounts** (dev project only; OTP `123456` via `[auth.sms.test_otp]` in `supabase/config.toml`):
Owner Anita Sharma `9876543210`; Manager Ramesh Kumar `9876500000` (assigned to HSR PG and Indiranagar PG);
Tenant Rahul Sharma `9822233445` (HSR PG, room B-204 bed A). A second manager, Divya S. `9900011122`, manages
Koramangala PG. `supabase/seed-users.mjs` creates these (needs service-role key in `.env.local`).

**Commands:** `dart format lib/ test/` → `flutter analyze` → `flutter test`. Backend: `supabase db push --linked`.
Never edit an applied migration; add a new numbered one. Ad-hoc SQL: `supabase db query --linked`.

**Verification method that worked:**
1. `flutter analyze` + `flutter test` after every change.
2. Test SQL/RPC changes inside `begin; … rollback;` first.
3. Test Edge Functions / RLS with scripts using the anon key and a real `signInWithOtp`/`verifyOtp` (test OTP),
   mirroring the request shape the Dart code sends.
4. Drive the real UI (Flutter web dev server + the app's browser pane) as each role.
5. Delete any real test data afterwards with a service-role script. **Example:** switching a demo account to
   Telugu during a live check writes `profiles.preferred_language`; reset all three demo accounts to `'en'`.

**Tooling gotchas**
- Flutter web renders via CanvasKit: DOM tools (`find`, `read_page`, `get_page_text`) return nothing useful; use
  screenshots. The first click after a screenshot often does not register; retry. Typing sometimes duplicates or
  drops; verify with a DB query rather than assuming. Dropdowns need slow click → wait → click.
- The preview server has no hot reload through these tools; `preview_stop` then `preview_start` to pick up source
  changes (about 20 to 30 s).
- Killing `flutter run` with `kill -9` leaves ~270 MB `flutter_tools.*` dirs under `/private/var/folders/…/T/`.
  Stop servers cleanly. Low disk space caused real compile failures on the original machine.
- zsh: lines like `echo =====` expand `=`; quote them. Globs with no match error out in zsh.
- `AppLocalizations.of(context)` is non-nullable in this project: do not add `!`.

---

## 10. Technical pitfalls already paid for (do not rediscover)

- **PostgREST:** an FK-ambiguous embed needs the constraint name (`profiles!property_managers_manager_user_id_fkey`).
  Embedding through a **view** does not work (no FKs); compose client-side. A missing RLS policy on an `!inner` embed
  silently returns zero rows.
- **RLS recursion:** policies must call `security definer` helper functions, never raw cross-table subqueries
  (hit twice: migrations 16 and 24).
- **pgcrypto:** `gen_random_bytes()` is not on the search_path of security-definer functions on hosted Supabase;
  use `gen_random_uuid()`.
- **Postgres literals:** a bare integer is `int4` and will not resolve to a `smallint` parameter; cast explicitly
  (`5::smallint`). This silently broke every invite-link join until fixed (migration 28).
- **Riverpod 3:** `AsyncValue.value` (no `valueOrNull`); `StateProvider` is in `legacy.dart`; `ref.listen` only fires
  on future transitions, so also read the already-resolved value; do not mix `.value` reads with awaiting another
  uninitialized provider's `.future` (can deadlock); start independent `.future`s before awaiting them.
- **Flutter layout:** `AlertDialog` queries intrinsic size even with `scrollable: true`, so no `GridView`/`ListView
  shrinkWrap`/`LayoutBuilder` inside dialogs (use `Row`s of `Expanded`). Avoid `GridView childAspectRatio` for
  text-driven cards (use `Row`s of `Expanded`). Put title/subtitle `Column`s in `Expanded` + ellipsis beside icon
  buttons. `Center`/`Align` shrink-wraps under unbounded height; theme `minimumSize: Size.fromHeight` means infinite
  min width (use `expand: false` in Rows).
- **Notification badge** provider must be `autoDispose` or it caches an empty result across logins.
- Add a new provider ⇒ widget tests that render screens using it must override it (tests broke when
  `currentAnnouncementProvider` was added).

---

## 11. Launch blockers (details in README section 4)

1. **Tenant "Pay Rent" moves no money.** `pay_rent_dialog.dart` waits 1.6 s and calls `record_self_payment`, which
   inserts a `paid` payment. Any tenant can mark rent paid. Integrate a gateway with webhook verification, or
   hide the button and rely on the confirm loop.
2. **OTP is test-only.** Remove `[auth.sms.test_otp]`, configure a provider (Twilio block exists, disabled; MSG91
   mentioned in `.env.example`); India needs DLT registration; delete demo users from production.
3. **`shared/widgets/document_scan.dart` returns fake people** (five hardcoded names). Remove or build real OCR.
4. **Reports occupancy trend is hardcoded** (`[78,80,83,85,84,86]` in `reports_providers.dart`).
5. **No production environment.** Single hosted project is dev + demo. Need a separate prod project, all 39
   migrations, functions deployed, `pg_cron` enabled.
6. Also: no automated RLS/RPC tests; no crash reporting; app identity still default (`pg_khata` Android label,
   template pubspec description); application id `com.pgkhata.pg_khata` must be final before Play upload; Android
   release signing via `key.properties`; iOS never verified; privacy policy/ToS/account deletion/DPDP; backups.

---

## 12. Security notes (read carefully)

- **Secrets were pasted into the original chat** on 2026-09-22: the Supabase **anon key, service-role key, project
  URL, database password**, a Supabase CLI **access token**, and earlier a GitHub **personal access token**. They are
  in the local transcript on the original laptop (and were sent to the model API as part of the conversation).
  None are in the repo or in this file. **Recommended: rotate the service-role key / JWT secret, change the DB
  password, revoke the access token and the GitHub PAT**, and make sure the original `.jsonl` transcripts are not
  shared or backed up somewhere public. Ask Shivam whether this has been done.
- Going forward, secrets live only in gitignored `mobile/.env` and `.env.local`. Never paste them into chat.
- **The GitHub repo `shivam-ventures/PG-Khata` was public** on 2026-11-01/04 (an unauthenticated API call
  succeeded). It contains the code, schema, and a README listing the launch blockers. Shivam was advised to make
  it private. Confirm current visibility.
- `supabase/config.toml` (committed) lists the demo phone numbers with OTP `123456`. That is dev-only and must be
  removed before production.
- Service-role key is only for server-side scripts and Edge Function secrets; the client ships only the anon key.

---

## 13. Product ideas and answers already given to the user

- **Marketplace:** worthwhile, built as a **separate web front-end on the same backend** (live vacancy data is the
  moat; SEO/no-install browsing suits web). Not started. Schema already has listing-safe public views.
- **Building as an entity:** recommended *not* to add; use floor labels like "Building A, 2nd Floor". Revisit only if
  a real multi-building owner is blocked.
- **Aadhaar:** real e-KYC needs a licensed AUA/KUA; practical route is a vendor at roughly ₹15 to ₹40 per
  verification, or offline XML/QR verification. V1 uses an uploaded ID photo with a manual "checked by staff" flag.
- **RoleSwitcher:** design-prototype aid only; never ship it. **Super Admin:** not needed.
- **Backlog ideas** (`docs/DECISIONS.md`): WhatsApp receipt per payment, owner weekly digest, manager nudge,
  offline-queue indicator.

---

## 14. Suggested next steps (in order)

1. Confirm repo is private and secrets are rotated (section 12).
2. Fix or hide the three "fake" features before any outsider uses the app: Pay Rent (blocker 1), document scan
   (3), occupancy trend (4).
3. Create the production Supabase project and a staging/prod split; deploy migrations and functions.
4. Real SMS provider (start DLT registration early).
5. pgTAP/SQL tests for RLS and the money-moving RPCs.
6. Finish localization gaps (dates, two onboarding screens, backend-generated text) and get Telugu reviewed.
7. App identity, icons, signing, store listings, privacy/ToS, crash reporting.
8. Back-fill `docs/DECISIONS.md` from this file's sections 3 and 8.
9. Pilot with one or two real PGs for a billing cycle.
