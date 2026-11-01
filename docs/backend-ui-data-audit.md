# Backend / UI data audit

Discovery pass for the production backend milestone (see `docs/backend-domain-model.md` for the
resulting domain model). Source of truth: the **actual Flutter code** in `mobile/lib/features/*`
as of 2026-09-21 — repository interfaces, mock implementations, domain classes, providers, and
screens — not the README (which is stale: it still says Payments/Complaints "not started," but all
three roles' Payments and Complaints screens are fully implemented and working) and not the
pre-pivot `supabase/schema.sql` (a different, earlier domain model — read and referenced, not
assumed current).

For each screen: data displayed, data required (inputs), user actions and their CRUD shape, status
changes, relationships assumed, validations, permissions assumed by the UI (not yet enforced by any
real backend), side effects on other screens, notification-worthy events, and audit-worthy
mutations.

---

## Auth / onboarding (unauthenticated)

### Phone Entry + OTP Verification (`phone_entry_screen.dart`, `otp_verification_screen.dart`)
- **Role:** anyone, signed out.
- **Data displayed:** none (just the login form).
- **Data required:** 10-digit Indian mobile number; 6-digit OTP.
- **Actions:** send OTP → verify OTP → resolves to an `AppUser` (id, name, phone, role) and signs
  in. `MockAuthRepository` currently resolves role from 3 hardcoded demo numbers; any other number
  becomes a brand-new Tenant with no property/bed — this "unknown number = new tenant" behavior is
  a **mock-only affordance**, not a real product rule (see domain model doc's ambiguity #3).
- **CRUD:** none against domain data; creates/reuses a session.
- **Relationships:** none yet — role resolution happens before any org/property context exists.
- **Validations:** phone format (10 digits, starts 6-9); OTP is 6 digits.
- **Permissions:** none — this is the entry point.
- **Side effects:** `go_router`'s redirect sends the user to their role's home once signed in.
- **Notifications:** the real OTP SMS itself (external, via Supabase Auth phone provider).
- **Audit:** login events are exactly the kind of thing worth a lightweight audit trail (who signed
  in, when) — low priority, not blocking.

### Join Invite (`join_invite_screen.dart`, `/join/:token`)
- **Role:** anyone, signed out — reachable without an existing account.
- **Data displayed:** the invite's property name, room, bed, rent/month (from `TenantInvite`,
  resolved from the token).
- **Data required:** phone, OTP, name.
- **Actions:** resolve token → send/verify OTP (same OTP mechanics as login) → confirm name →
  **`completeInviteJoin`**, which does four things in sequence today (not atomically — see domain
  model doc §11 Transactions): creates a `TenantRecord` (`addTenant`), occupies the invited bed
  (`occupyBed`), consumes the invite token (`consumeInvite`), and signs the person in as a new
  Tenant session.
- **CRUD:** Create tenant, Update bed occupancy, Update invite (consumed).
- **Status changes:** bed vacant → occupied; invite token unused → used.
- **Relationships:** invite token → property + room + bed (today: derived from the token string
  `propertyId-room-bed`, not a persisted row — see ambiguity #4).
- **Validations:** invite must resolve (not found / already used → `InviteNotFoundFailure` /
  `InviteAlreadyUsedFailure`); name ≥ 2 chars.
- **Permissions:** none enforced — anyone with a valid token link can join. No approval step; the
  tenant becomes `active` immediately (no `pending_profile` / staff-approval stage exists in current
  code, unlike the richer flow sketched in `docs/DECISIONS.md`'s 2026-09-15 entry).
- **Side effects:** the bed disappears from every "vacant beds" count across Owner/Manager screens
  the moment this completes.
- **Notifications:** would want to tell the Manager/Owner "a tenant just joined via your invite
  link" — not built.
- **Audit:** who created this tenancy (self-joined vs staff-created) should be recorded —
  `TenantRecord` has no `createdBy`/`source` field today.

---

## Owner screens

### Owner Dashboard (`owner_dashboard_screen.dart`, `dashboard_providers.dart`)
- **Role:** Owner.
- **Data displayed:** greeting; up to 3 "needs attention" items (pending rent total + tenant count,
  vacant beds + which properties, complaints open >48h); a 4-stat grid (occupancy %, rent collected
  vs expected, pending rent, open complaints — **portfolio-wide**, summed across every property);
  per-property overview cards (occupancy, rent collected/expected, open complaints, manager name).
- **Data required:** none (read-only).
- **Actions:** tap an attention item → navigates to Payments/Rooms/Complaints; tap a property card →
  navigates into it; "Add PG" quick action when the portfolio is empty.
- **CRUD:** Read only. Everything here is **computed live** from Properties + Rooms + Payments +
  Complaints (`propertyMetricsProvider` — see domain model doc, this is the pattern the real
  database must replicate so these numbers can never drift from what Payments/Rooms/Complaints
  themselves show).
- **Relationships:** spans every property the signed-in Owner has — i.e. **all** properties in this
  Owner's organization. No org-scoping exists yet in the mock (there's only ever one Owner's data in
  memory); the real backend must scope this to "properties this org_id owns."
- **Permissions:** Owner-only screen. Must never include another Owner's properties.
- **Notifications/audit:** none of its own — it's a read rollup of events that originate elsewhere.

### Owner Properties / "PGs" (`owner_properties_screen.dart`, `properties_providers.dart`)
- **Role:** Owner.
- **Data displayed:** portfolio summary (count of PGs, total beds — computed); per-property card:
  name, address, occupancy (computed from Rooms), open complaints (computed), rent collected/expected
  (computed).
- **Data required (Add/Edit PG dialog):** name, address, total beds (int), manager name (free-text
  today — see ambiguity #1, this is not a real manager account reference).
- **Actions:** Add PG, Edit PG, bulk **Import PGs from CSV** (`import_properties_dialog.dart`,
  `property_import_row.dart` — parses name/address/total beds/manager name, skips invalid rows with
  a visible error per row), tap a card → Rooms for that property.
- **CRUD:** Create, Update. **No delete/archive exists in the repository interface at all** — this
  is a real gap the real backend must close (an Owner will eventually stop using a property; hard
  delete is never correct once rooms/tenants/payments exist under it — see domain model doc §6).
- **Status changes:** none (`Property` has no status field today).
- **Relationships:** one property → many rooms (via `roomsProvider(property.id)`); property →
  manager (free-text name only, not a real FK — see ambiguity #1).
- **Validations:** name/address non-empty; total beds > 0; manager name non-empty. CSV import
  validates the same fields per row.
- **Permissions:** Owner-only. A Manager never sees this screen (Manager's own Rooms screen shows
  occupancy for their one selected PG, no property-level CRUD).
- **Side effects:** changing `totalBeds` here is **purely declarative capacity** — it does not
  create/remove actual `Room`/`Bed` rows; a real Owner would still use Rooms to add actual rooms.
  This is a real UX gap worth flagging (see ambiguity #7) but out of scope to fix in the backend
  milestone.
- **Audit:** property creation/edits are meaningful mutations worth logging (who changed the address,
  when).

### Owner Rooms (`owner_rooms_screen.dart`, floor-grouped, via Properties → tap a PG)
- **Role:** Owner.
- **Data displayed:** floors, each with rooms (number, sharing type, rent/bed, beds with
  vacant/occupied state and occupant name).
- **Data required (Add Room dialog):** floor (free text), room number, sharing type (enum, fixes bed
  count 1-4), rent per bed.
- **Actions:** switch between the Owner's properties (a property switcher, not `managerSelectedPgIdProvider`
  — Owner has its own selection state); Add Room; tap a vacant bed → "+ Add tenant" (opens the Add
  Tenant dialog pre-filled with this room/bed).
- **CRUD:** Create room (with N auto-generated vacant beds, labeled A/B/C.../ per `SharingType.bedCount`).
  **No edit/delete room, no edit/delete bed** exists in the interface.
- **Status changes:** bed vacant → occupied happens indirectly, via Tenants' `addTenant`/`assignPendingTenant`
  calling `RoomsRepository.occupyBed` — Rooms and Tenants are two screens over the same underlying
  occupancy fact, which is exactly why the real backend must derive bed occupancy from tenancies
  rather than storing it twice (see domain model doc §6, "Property/Rooms drift" bug class already
  hit once this session at the `Property` stats level).
- **Relationships:** property → floor (free-text label, not an entity) → room → beds.
- **Validations:** room number/floor non-empty; rent per bed > 0. **No uniqueness enforced today**
  (nothing stops two rooms sharing a number, or two beds sharing a label in the same room) — the mock
  simply appends. Real backend needs an explicit decision here (see domain model doc §13).
- **Permissions:** Owner-only screen (Manager has its own Rooms screen, scoped to one PG, no property
  switcher).
- **Audit:** room creation is a meaningful mutation.

### Owner Tenants (`owner_tenants_screen.dart`, whole-portfolio roster)
- **Role:** Owner.
- **Data displayed:** every tenant across every property (name, phone, property, room/bed, rent,
  joined date, status chip); search + property filter; a "Self-registered — needs a bed" section for
  `PendingTenant`s.
- **Data required (Add/Edit Tenant dialog):** name, phone, property, room/bed, rent, joining date,
  status, deposit amount (optional). **Assign pending tenant dialog:** room/bed, rent, joining date,
  deposit (name/phone/property come from the existing `PendingTenant`).
- **Actions:** Add Tenant (direct — no separate profile-completion step); Assign a pending tenant to
  a bed; bulk **Import Tenants from CSV** (`import_tenants_dialog.dart`/`tenant_import_row.dart` —
  name/phone/room-bed/rent); scan a paper form via device camera as an input shortcut
  (`document_scan.dart` — a **mocked OCR convenience that only pre-fills the Add Tenant form's
  name/phone fields**, does not store any photo/document anywhere; not an identity-verification
  feature); Move out a tenant (frees the bed).
- **CRUD:** Create tenant, Update (implicitly, via move-out only — there's no general "edit an
  existing active tenant's rent/room" flow in the interface beyond `addTenant`/`assignPendingTenant`/
  `moveOutTenant`).
- **Status changes:** `active` / `noticePeriod` / `vacated`. Move-out: `→ vacated`, appends
  `" (freed)"` to the stored `roomBed` string (a mock-only display hack — the real schema must
  represent "which bed, historically" without string concatenation), and does **not** call
  `RoomsRepository` to actually free the bed in the Rooms data — **a real drift bug already latent in
  the mock**, worth noting for the real backend: move-out must atomically flip both the tenancy status
  and the bed's derived-vacant state (trivial once occupancy is derived from tenancy status rather
  than stored twice).
- **Relationships:** tenant → property (by id) + room/bed (by a formatted string, not a bed FK) —
  see ambiguity #6, this is one of the bigger real gaps: `TenantRecord.roomBed` is a display string
  ("101 - A"), not a foreign key to an actual `Bed` row.
- **Validations:** name/phone non-empty; rent > 0; a bed can be assigned to more than one active
  tenant simultaneously in the mock (**not prevented anywhere** — a real invariant the database must
  enforce, since the app-layer currently doesn't).
- **Permissions:** Owner sees every property; a Manager would need to be restricted to their assigned
  property/properties (not enforced anywhere today — see ambiguity #1).
- **Notifications:** tenant added / moved out could notify the property's manager — not built.
- **Audit:** tenant creation, move-out, and rent changes are all meaningful financial/occupancy
  events worth logging.

### Owner Payments (`owner_payments_screen.dart`, portfolio rent ledger)
- **Role:** Owner.
- **Data displayed:** portfolio stats (collected, pending, overdue, collection rate, needs review);
  every tenant's **current period** payment row, filterable by property/status.
- **Data required (Record Payment dialog):** method (cash/UPI/card/bank transfer), amount, date.
  (Void dialog needs only a confirmation.)
- **Actions:** Record a payment on a tenant's behalf; Void a payment (undo a mistaken entry).
- **CRUD:** Update (a payment period's state) — payments aren't created here; every tenant already
  has a `RentPayment` row per period seeded/generated elsewhere (see Payments screen note below on
  where periods come from — this is itself an open question, ambiguity #8).
- **Status changes:** any staff-recorded payment (Owner or Manager, any method) goes to
  `awaitingConfirmation`, **never straight to `paid`** — only the tenant's own in-app payment
  (`recordSelfPayment`) settles instantly. This is the "UPI/QR-of-owner should auto-mark-paid" rule
  the product owner specifically flagged earlier this session, already correctly implemented:
  `PayRentDialog` (tenant-initiated) → `recordSelfPayment` → `paid` immediately;
  `RecordPaymentDialog`/`CollectRentDialog` (staff-initiated, any method including UPI they claim was
  paid to them) → `recordPayment` → `awaitingConfirmation`, because the app itself never verified the
  transaction. Voiding restores `pending`/`overdue` (whichever the due date implies), the tenant's
  on-record rent amount, and clears method/paid date.
- **Relationships:** payment → tenant, property (denormalized: `tenantName`/`propertyName` strings
  copied onto every `RentPayment`, not just FKs — fine for a mock, a real schema resolves these via
  joins instead of redundant copies).
- **Validations:** amount > 0 (dialog-level); **no invariant preventing a payment being recorded
  twice, or an amount wildly different from expected, beyond a soft warning comparing to
  `expectedAmount`.**
- **Permissions:** Owner sees the whole portfolio; scoping to org would apply here.
- **Notifications:** tenant should be notified "a cash payment was recorded, please confirm" — not
  built (design's own `Tenant Home` "pending cash confirmation" banner exists, but no push/SMS).
- **Audit:** **payments are the highest-audit-priority entity in the whole app.** Every record/void/
  confirm/dispute must be traceable to who did it and when — `RentPayment` today has no `recordedBy`
  field at all.

### Owner Reports (`owner_reports_screen.dart`, `reports_providers.dart`)
- **Role:** Owner.
- **Data displayed:** total revenue vs expected, avg occupancy %, avg days late (computed from
  `paidDate - dueDate` across paid payments), complaint resolution %; revenue-by-property bars; a
  6-month occupancy trend (**currently hardcoded illustrative percentages**, not derived from real
  historical occupancy — there is no historical occupancy snapshot anywhere to compute this from
  honestly); property comparison rows.
- **Data required:** none (read-only).
- **CRUD:** Read only, portfolio-wide aggregation.
- **Relationships/validations/permissions:** same portfolio scope as Dashboard.
- **Notable backend implication:** a real occupancy trend needs either (a) periodic snapshots of
  occupancy stored over time, or (b) derivation from tenancy start/end date history once that exists
  — not answerable from current mock data alone (see ambiguity #9).

### Account Menu / Settings (`account_menu_screen.dart`)
- **Role:** all three, rendered inside each role's shell.
- **Data displayed:** name, role, phone.
- **Actions:** Log out. Everything else ("Profile, notification preferences and language") is an
  explicit placeholder — not built.
- **CRUD:** none.
- **Backend implication:** none yet; `profiles` needs to support this later without a schema change
  (name/phone/role already cover it).

---

## Manager screens

### Manager Today (`manager_today_screen.dart`)
- **Role:** Manager.
- **Data displayed:** greeting; occupancy (this PG only); pending rent total; open complaints count;
  a rent-to-collect task list; an open-complaints task list.
- **Data required:** none (read-only).
- **Relationships:** scoped to **one property at a time** — `managerSelectedPgIdProvider`, a
  **client-only UI selection defaulting to `'hsr'` with no authorization check whatsoever.** Any
  signed-in Manager can currently select any property id and see its data. This is the single
  biggest authorization gap the real backend must close — see domain model doc §5/§9 and ambiguity
  #1.
- **Permissions:** intended to be "properties this Manager is assigned to," not enforced anywhere
  today.

### Manager Rooms (`manager_rooms_screen.dart`, flat list for the selected PG)
- Same data/actions as Owner Rooms, minus the property switcher (Manager operates on
  `managerSelectedPgIdProvider`'s current PG only) — plus **"Invite via link"**
  (`invite_tenant_dialog.dart`): generates a bed-specific invite token (today: literally the string
  `"$propertyId-$room-$bed"`, not a persisted, expiring, revocable row — see ambiguity #4) and shows
  it to copy/share. No "Assign existing" tenant-picker action was found wired into this screen
  currently (only the Owner-parallel "+ Add tenant" path and the invite-link path).

### Manager Tenants (`manager_tenants_screen.dart`, via More → Tenants, one-PG roster)
- Same shape as Owner Tenants, scoped to the Manager's currently-selected PG instead of the whole
  portfolio, plus deep-link params (`initialRoom`, `initialBed`, `autoOpenAdd`) so Rooms' "+ Add
  tenant" can jump here pre-filled.

### Manager Payments (`manager_payments_screen.dart`, Collect Rent)
- Same shape as Owner Payments, scoped to the selected PG; the primary action is framed as "Collect
  rent" (`collect_rent_dialog.dart`) rather than "Record payment," same underlying `recordPayment`
  call and same `awaitingConfirmation` outcome for every method.

### Manager Complaints (`manager_complaints_screen.dart`, via More)
- **Role:** Manager.
- **Data displayed:** complaints for the selected PG, sorted high-severity first (by original
  severity, not by current status); each shows title, category, severity, room, tenant, reported
  time, and effective status (auto-resolve-aware).
- **Data required (delegate dialog):** assignee (one of 5 fixed **free-text labels**: "Self (I'll fix
  it)", "Cleaner", "Electrician", "Plumber", "Outside vendor" — **not real accounts/contacts**),
  optional note.
- **Actions:** Delegate (Reported/Reopened → Delegated); the dialog also allows re-delegating a
  Delegated/Resolved complaint ("Reassign" escape hatch); no direct "Resolve" button surfaced in the
  Manager UI — resolution happens automatically 3 days after delegation (`effectiveStatus`, computed
  client-side from `delegatedAt`), or manually via `resolveComplaint`/`reopenComplaint` which exist on
  the repository but are primarily tenant-triggered (see Tenant Complaints below).
- **Status changes:** `reported`/`reopened → delegated` (sets `delegatedTo`, `delegatedAt`, `note`);
  `delegated → resolved` is a **derived, not stored, transition** — `Complaint.effectiveStatus`
  computes it live from "now - delegatedAt >= 3 days," exactly like the design's own
  `effectiveStatus()` JS function, which its own README already flags as something that "should be a
  scheduled/derived server-side status" in production (see domain model doc §7, payment/complaint
  state machine).
- **Relationships:** complaint → property, optionally → tenant (nullable — a common-area complaint
  like "Wifi down on 2nd floor" has `tenantId: null`, `tenantName: 'Multiple tenants'`).
- **Permissions:** scoped to the Manager's selected PG (same unenforced-scoping gap as everywhere
  else).
- **Notifications:** tenant should be notified on delegation/resolution — not built.
- **Audit:** delegation history is currently **overwritten, not appended** — `delegateComplaint`
  replaces `delegatedTo`/`delegatedAt`/`note` in place, so re-delegating loses who was assigned
  before. A real complaint timeline needs an append-only event log (see domain model doc §7).

---

## Tenant screens

### Tenant Home (`tenant_home_screen.dart`)
- **Role:** Tenant.
- **Data displayed:** PG name/address, room, manager name; current period rent amount and due
  status (due soon / overdue / next due date); a "pending cash confirmation" banner when applicable;
  up to 3 recent paid-payment summaries; open complaint title/age/status if any.
- **Data required:** none (read-only).
- **Relationships:** resolved via `currentTenantRecordProvider` — matches the signed-in user's
  **phone number** against the tenant roster (a mock-only mechanism; real backend resolves this via
  `tenancies.profile_id = auth.uid()`, not a phone-string match).
- **Permissions:** a tenant only ever sees their own data — this is the one role where "the UI
  already only fetches the right thing" happens to hold today, but per the mega-prompt's own
  instruction this must still be enforced at the database layer (RLS), not assumed from app
  correctness.

### Tenant Payments (`tenant_payments_screen.dart`)
- **Role:** Tenant.
- **Data displayed:** current rent card; full payment history (every period).
- **Data required (Pay Rent dialog):** method (UPI/card — this is the tenant's *own* in-app payment
  path), amount, date.
- **Actions:** Pay rent (self-pay → `recordSelfPayment` → `paid` instantly, per the auto-mark-paid
  rule); Confirm a cash payment a Manager/Owner recorded (`confirmPayment` →
  `awaitingConfirmation → paid`); Dispute one (`disputePayment` →
  `awaitingConfirmation → disputed`).
- **Status changes:** as above. **Who resolves a `disputed` payment, and how, is undesigned** — no
  screen anywhere (Owner, Manager, or Tenant) shows an action for a `disputed` payment beyond it
  sitting there with that status chip. This is a real open gap, not just a documentation one — see
  ambiguity #2.
- **Permissions:** a tenant can only act on their own payments (enforced by which `paymentId`s the
  screen ever shows them, not by any deeper check).
- **Audit:** confirm/dispute are exactly the kind of tenant-initiated financial assertions that need
  a timestamp + actor trail.

### Tenant Complaints (`tenant_complaints_screen.dart`)
- **Role:** Tenant.
- **Data displayed:** the tenant's own complaints, with effective status.
- **Data required (Report Issue dialog):** category (plumbing/electrical/wifi/cleaning/other),
  severity (low/medium/high), title, preferred time-to-fix.
- **Actions:** Report a new complaint (`reportComplaint` → `reported`); "still not fixed?" reopen a
  Delegated/Resolved complaint (`canReopen` — `reopenComplaint` → `reopened`).
- **Relationships:** complaint → the reporting tenant + their property (both filled from
  `currentTenantRecordProvider`, never user-chosen).
- **Validations:** title required (falls back to "`{category}` issue" if left blank).
- **Permissions:** a tenant only ever reports/reopens against their own tenancy.
- **Notifications:** Manager should be notified of a new/reopened complaint — not built.
- **Audit:** report/reopen events, same reasoning as Manager Complaints above.

---

## Cross-cutting observations that shaped the domain model doc

1. **`propertyMetricsProvider` is the load-bearing pattern of this whole codebase.** Occupancy, rent
   collected/expected, and open-complaint counts are *never* stored fields — they're computed live
   from Rooms/Payments/Complaints, specifically because a stored, independently-seeded copy on
   `Property` was found to drift from reality earlier this session. The real database must replicate
   this: no denormalized occupancy/financial rollups stored on `properties`, ever. Views/queries, not
   columns.
2. **The Manager "which property" selection has zero real authorization behind it.** This is the
   single most important gap to close — see domain model doc's ownership model and RLS strategy.
3. **`TenantRecord.roomBed` is a display string, not a foreign key.** The real schema needs tenancies
   to reference an actual `bed_id`.
4. **Every staff-recorded payment goes to `awaitingConfirmation`; only a tenant's own in-app payment
   settles instantly.** This is already the correct trust model (verified this session) and the real
   backend must preserve it exactly — do not "simplify" it to auto-paid-on-any-method.
5. **Complaint delegation history is overwritten in place**, and complaint auto-resolution is a
   derived/computed value, never stored — both patterns the real schema should keep (derived status),
   except delegation needs an append-only event log underneath it (state, not just the *current*
   state).
6. **No delete/archive exists anywhere in any repository interface.** Every "remove" action in the
   current UI is actually a status change (tenant → vacated, payment → voided) or doesn't exist yet
   (properties/rooms have no removal path at all).
7. **Identity documents, tenant profile-completion (emergency contact, house-rules acceptance), and
   self-registration are all designed in `docs/DECISIONS.md` but not built in any current screen.**
   The one document-adjacent feature that exists (`document_scan.dart`) is a mocked OCR
   form-fill convenience, not identity verification/storage.
