# Backend domain model — discovery & architecture proposal

**Status: DRAFT FOR REVIEW. No migrations exist yet. Nothing here is implemented.**

This is the discovery/architecture phase for the production Supabase/PostgreSQL backend, requested
after Phase 0-1 (Flutter UI, fully mocked) was completed and polished. It follows
`docs/backend-ui-data-audit.md` (read that first — every claim below about "what the UI actually
does" is sourced from it, which is sourced from the real Flutter code, not the README).

Three inputs were reconciled to reach the proposal below:
1. **The current Flutter app** (`mobile/lib/features/*`) — the strongest signal for what's actually
   being built and how it behaves, per the instruction to treat the UI as evidence of the domain, not
   as the schema itself.
2. **The pre-pivot `supabase/schema.sql`** — a real, carefully-reasoned prior design (organizations,
   profiles/tenant_profiles identity split, tenancies, RLS patterns) for an *earlier, more ambitious*
   version of the product (cross-owner tenant discovery, self-registration, WhatsApp conversational
   onboarding). The README explicitly says this "reflects an older domain model... revisited
   deliberately once the database phase starts, not reused as-is" — so it's treated as a rich source
   of prior thinking to borrow good ideas from (the identity/tenancy split, the RLS helper-function
   pattern), not a schema to reuse wholesale.
3. **`docs/DECISIONS.md` and `docs/domain-model-notes.md`** — the running product-decision log and
   the discovery notes from implementing the design. Both are still valid; several of their "open
   questions" are answered below where the current code has since settled them, and left open where
   it hasn't.

**Where these three disagree, the current Flutter code wins**, per this repo's own established
reconciliation rule ("where the screens and earlier docs disagree, the screens win" —
`docs/design-readme-reconciliation.md`). Where the current code is silent on something the mega-scale
of a real financial/multi-tenant system requires (e.g. tenancy history, manager assignment
many-to-many), the pre-pivot schema and the product docs fill the gap, flagged explicitly as a
schema-only provision the current UI doesn't yet exercise.

---

## 1. Final entity list

| Entity | Table | New vs. current UI vs. pre-pivot schema |
|---|---|---|
| Auth identity | `auth.users` (Supabase-managed) | Unchanged — phone OTP |
| Profile | `profiles` | Matches pre-pivot shape closely; role enum trimmed to 3 (no `super_admin` — see §12.7) |
| Tenant identity extension | `tenant_profiles` | Adopted from pre-pivot (see §12.2 for the identity/tenancy split decision this requires) |
| Organization | `organizations` | Adopted from pre-pivot — current UI has no concept of it (single implicit Owner), but multi-tenant SaaS requires it from day one |
| Property | `properties` | Matches current `Property` domain class closely (name, address, total_beds) + `org_id`, `archived_at` |
| Property↔Manager assignment | `property_managers` | **New** — replaces current UI's free-text `Property.managerName` with a real many-to-many join (see §12.1) |
| Room | `rooms` | Matches current `Room` domain class (floor as free-text column, no separate Floor entity — matches current code exactly) |
| Bed | `beds` | Matches current `Bed` shape, **minus** a stored `status` column — occupancy is derived (see §6, §8) |
| Tenancy | `tenancies` | Adopted from pre-pivot, **simplified** to match what's actually built today (no pending_approval/pending_profile states — see §8) |
| Rent obligation | `rent_periods` | **New** — current mock's `RentPayment` conflates "what's owed this month" and "what was paid"; splitting these is required for partial payments (see §7) |
| Payment | `payments` | Matches current `RentPayment`'s payment-side fields; no longer also carries the "amount owed" (that's `rent_periods`) |
| Complaint | `complaints` | Matches current `Complaint` domain class |
| Complaint event | `complaint_events` | **New** — append-only history under `complaints`, since the mock overwrites delegation history in place (see §7's complaint section) |
| ID document | `id_documents` | Adopted from pre-pivot **schema-only** — no current UI writes to this yet (see §10, §12.5) |
| Tenant invite link | `tenant_invite_links` | Adopted from pre-pivot, **persisted** (current mock derives the token from a string pattern — see §12.4) |
| Notification | `notifications` | **New**, minimal — in-app only, no delivery-channel coupling (see §32 in `docs/architecture.md`, unchanged conclusion) |
| Audit log | `audit_log` | **New** — see §4 |
| ~~Building~~ | — | **Not modeled** — no screen anywhere manages a Building level; Property is the top physical unit (matches `docs/domain-model-notes.md`'s own recommendation) |
| ~~Floor (as entity)~~ | — | **Not modeled** — stays a free-text column on `rooms`, exactly matching current code |
| ~~PropertyMetrics~~ | *(view, not a table)* | Computed, never stored — see §6 |
| ~~WhatsApp conversations / reminder log~~ | — | **Deferred entirely**, not even as an unused table — Phase 4+ per `docs/DECISIONS.md`, no current UI references it, and adding it later costs nothing structurally |
| ~~Announcements~~ | — | **Deferred** — no authoring UI exists anywhere (`docs/design-readme-reconciliation.md` already flagged this as needing its own design pass first) |

---

## 2. Entity relationship proposal

```
auth.users (Supabase)
  └─ profiles (1:1)                              role: owner | manager | tenant
       ├─ organizations.owner_user_id (1:1, only when role=owner)
       ├─ tenant_profiles (1:1, only when role=tenant, created on first tenancy)
       └─ property_managers.manager_user_id (1:N, only when role=manager)

organizations (one per Owner)
  └─ properties (1:N)
       ├─ property_managers (N:M → profiles, role=manager)
       ├─ rooms (1:N)
       │    └─ beds (1:N)
       │         └─ tenancies (1:N over time; at most ONE active at a time — enforced)
       │              ├─ profile_id → profiles (role=tenant)      [WHO]
       │              ├─ bed_id → beds                            [WHERE]
       │              ├─ rent_periods (1:N, one per month owed)
       │              │    └─ payments (1:N — supports partial/multiple payments per period)
       │              ├─ id_documents (1:N, scoped to THIS tenancy, not the identity)
       │              └─ tenant_invite_links (0:1, if self-serve joined)
       ├─ complaints (1:N)
       │    ├─ tenancy_id → tenancies (nullable — common-area complaints)
       │    └─ complaint_events (1:N, append-only timeline)
       └─ (org-scoped) audit_log entries referencing any of the above

notifications  — recipient_user_id → profiles, references any entity generically (entity_type + entity_id)
audit_log      — actor_user_id → profiles, org_id, references any entity generically
```

Key structural difference from the current Flutter app: **a `Payment` no longer carries the amount
owed.** `rent_periods` is "what's due this month for this tenancy" (created when a tenancy starts,
one row per month); `payments` is "money that arrived," which can be zero, one, or several rows
against one `rent_period` (partial payments), or — via `payment_allocations`, see §7 — split across
more than one period (an advance/lump payment covering two months). This is the one place the real
schema **must** diverge from a literal port of `RentPayment`, because `RentPayment.amount` doing
double duty as both "owed" and "paid" cannot represent a partial payment at all, and the mega-scale
requirement (§9 of the request) explicitly needs this.

---

## 3. Business rules / invariants

| Invariant | Where enforced |
|---|---|
| A bed has at most one **active** tenancy at any time | DB: partial unique index `ON tenancies (bed_id) WHERE status = 'active'` |
| A tenancy's bed must belong to a room in the same property the tenancy is scoped to (no cross-property bed assignment) | DB: `beds`→`rooms`→`properties` FK chain is the only path; no `property_id` duplicated onto `tenancies` to go stale — always resolved via the join. (A denormalized `tenancies.property_id`, kept in sync by a trigger, is worth adding purely as a query/RLS-performance optimization — see §9 — but the FK chain is the source of truth either way.) |
| A Manager can only read/write properties they're assigned to via `property_managers` | RLS (see §9) |
| An Owner can only read/write properties in their own `organization` | RLS |
| A Tenant can only read their own `tenancies`/`payments`/`complaints`/`id_documents` | RLS |
| Cross-organization references are impossible (Owner A can't see Owner B's anything) | RLS + every FK chain rooted at `organizations.id`, never a bare cross-org id |
| A payment can never be recorded against another org's tenancy | RLS (insert policy checks the tenancy resolves to the caller's own org/scope) + FK |
| Sum of a rent period's `payments.amount` (or allocations, see §7) should not silently exceed what's owed without it being visible as an overpayment/credit, not a validation error | Application layer surfaces it; DB does not hard-block (real PGs do get overpaid on purpose — advance rent) |
| A payment's status transitions follow the state machine in §7 exactly — no direct jump e.g. `pending → paid` bypassing `awaitingConfirmation` for a staff-recorded payment | DB: `CHECK` constraint on valid status values + a Postgres function (`record_payment`, `confirm_payment`, etc.) that's the *only* sanctioned write path for a status change — application code never does a raw `UPDATE payments SET status = ...` (see §11) |
| Only the tenant themself can confirm/dispute their own payment | RLS + the RPC checks `auth.uid()` matches the tenancy's `profile_id` |
| A complaint's `delegated → resolved` transition is time-derived (3 days), never independently stored as a second source of truth | Computed in a view/function at read time (`effective_status`), mirroring `Complaint.effectiveStatus` in Dart exactly — **not** a cron job that flips a stored column, so it can never drift from "now" |
| Complaint delegation changes are never overwritten — each delegate/reassign/resolve/reopen appends a `complaint_events` row | Application writes always insert into `complaint_events`; `complaints.status` is a cached "current" pointer kept in sync by a trigger reading the latest event, not hand-maintained in two places |
| Historical financial records (payments, rent_periods) are never hard-deleted, only voided/reversed with a trail | No `DELETE` grant on `payments`/`rent_periods` for any client role; `void_payment` RPC inserts a reversal, never removes a row |
| A tenant's `id_documents` uploaded within one org are never visible to a different org, even for the same person | RLS scopes by `tenancy_id`'s org, not by `profile_id` alone — this is the whole point of the identity/tenancy split (see §12.2) |
| An occupancy/financial rollup is never stored where it can drift from the ledgers that back it | No `occupied_beds`/`rent_collected`/etc. columns on `properties` — always a view (`property_metrics`, mirroring the Flutter `propertyMetricsProvider` pattern exactly) |

---

## 4. Ownership model

Every table answers "who owns this row" via one unbroken FK chain rooted at `organizations`:

```
organizations.id
  → properties.org_id                (direct)
    → rooms.property_id              (direct)
      → beds.room_id → rooms         (indirect, via rooms)
        → tenancies.bed_id → beds    (indirect, via beds/rooms)
          → rent_periods.tenancy_id  (indirect)
            → payments.rent_period_id (indirect)
          → id_documents.tenancy_id  (indirect)
    → complaints.property_id         (direct — complaints also carry a nullable tenancy_id)
```

**Decision: do not duplicate `org_id` onto every descendant table "for convenience."** The one
exception worth making, purely for RLS/query performance at scale (thousands of tenants, years of
payment history — the mega-scale scenario in the request), is a **denormalized, trigger-maintained
`org_id` on `tenancies`, `payments`, and `complaints`** — the three tables a policy check would
otherwise have to join 3-4 levels deep for on every single row read. This is the one place a
duplicated ownership column is justified (RLS performance, not application convenience) — every
other table stays normalized and resolves ownership via its direct parent FK. Documented here so a
future reader doesn't wonder why these three tables look inconsistent with the rest.

**Managers are not owners.** `property_managers` grants *scoped access*, not ownership — a Manager's
RLS reads are always "properties I'm assigned to within someone else's org," never "my org."

**Tenants are not scoped to an organization at all** — per the identity/tenancy split (§12.2), a
tenant's `profiles`/`tenant_profiles` row has no `org_id`. Their access is entirely per-tenancy:
"rows where `tenancies.profile_id = auth.uid()`," which can span multiple orgs over a lifetime if the
cross-owner model is adopted (open question, §12.2) or exactly one org if it isn't.

---

## 5. Delete / archive strategy

| Entity | Delete type | FK behavior (on parent delete) | Reason |
|---|---|---|---|
| `organizations` | Never deleted by a client role (support-only, out of band) | — | An Owner's entire business; deleting this is an offboarding operation, not a UI action |
| `properties` | **Archive** (`archived_at timestamptz`) | Children: `ON DELETE RESTRICT` (an org can't be deleted while it has properties, forcing the archive path) | An archived property stops appearing in "add tenant"/"add room" flows and portfolio totals, but every historical room/tenancy/payment/complaint under it stays queryable — required for the Owner's own historical Reports |
| `rooms` | **Archive** (`archived_at`) | `ON DELETE RESTRICT` if it has ever had a tenancy (even a moved-out one) — hard delete only allowed if it never has | A room that was never occupied can be a genuine mistake, safe to hard-delete; one with any tenancy history must be preserved for that tenancy's record |
| `beds` | Same as rooms — archive if ever occupied, hard-delete otherwise | `ON DELETE RESTRICT` if `tenancies` reference it | Same reasoning |
| `property_managers` | **Soft** — `unassigned_at timestamptz`, row kept | `ON DELETE CASCADE` from `properties`/`profiles` only in the genuine account-deletion case | "Who managed this property when" is worth keeping, e.g. for accountability on old payments/complaints they handled |
| `tenancies` | **Never deleted** — status-driven (`active → notice_period → moved_out`) | `ON DELETE RESTRICT` from `beds`/`profiles` (a bed/profile can't be hard-deleted while any tenancy references it) | This *is* the historical record — see §8 |
| `rent_periods` | **Never deleted** | `ON DELETE RESTRICT` from `tenancies` | Financial history |
| `payments` | **Never deleted** — corrections are a new reversal row (`void_payment`), not a delete | `ON DELETE RESTRICT` from `rent_periods` | Matches the current mock's own `voidPayment` semantics ("there is no separate edit action... the ledger never silently rewrites what was actually entered") — the real schema keeps that promise by disallowing delete outright, not just by app-layer convention |
| `complaints` | **Never deleted**, status-driven | `ON DELETE RESTRICT` from `properties`/`tenancies` | A resolved/reopened complaint is a real service-history record |
| `complaint_events` | **Never deleted** — append-only | `ON DELETE CASCADE` from `complaints` (only if the parent complaint itself is ever purged, which it isn't in practice) | Timeline integrity |
| `id_documents` | **Soft** — a re-upload inserts a new row and marks the old one superseded, doesn't overwrite; hard-delete only via an explicit "remove this document" action, which should be rare and audited | `ON DELETE CASCADE` from `tenancies` | If a tenancy is preserved forever, its documents are too, by default — but a document is more privacy-sensitive than a payment, so an explicit removal path (GDPR-style "please delete my ID photo") should exist even though nothing in the current UI asks for one yet |
| `tenant_invite_links` | **Hard delete acceptable** after expiry (housekeeping only) | `ON DELETE CASCADE` from `tenancies` | Ephemeral by nature; no historical value once expired/used |
| `notifications` | **Hard delete acceptable** (read receipts don't need forever-retention) | `ON DELETE CASCADE` from recipient | Not financial, not identity — pure UX convenience data |
| `audit_log` | **Never deleted** | No FKs with cascade — references are soft (entity_type + entity_id), so it outlives whatever it logged | The point of an audit log is that it survives the thing it's auditing being archived/changed |

**No entity gets a blind `deleted_at` "just in case."** Every row above was evaluated individually
against "does deleting this destroy something a real PG business needs later" — per the instruction
not to reflexively soft-delete everything.

---

## 6. Bed occupancy — derived, not stored

This is worth its own section because it's the single most important structural decision, directly
informed by a bug this session already hit once (`Property`'s stored `occupiedBeds`/`rentCollected`
drifting from the real Rooms/Payments ledgers, fixed by replacing them with a live-computed
`PropertyMetrics`).

**Decision: `beds` has no `status` column.** Whether a bed is vacant or occupied is always derived:

```sql
create or replace view bed_occupancy as
select b.id as bed_id,
       t.id as active_tenancy_id,
       t.id is not null as is_occupied
from beds b
left join tenancies t
  on t.bed_id = b.id and t.status = 'active';
```

This differs from the pre-pivot schema (which had a stored `beds.status` with `vacant/occupied/hold`)
on purpose: a stored status is a second copy of a fact the `tenancies` table already states, and
every one of this session's already-fixed bugs was exactly this class of drift. The partial unique
index in §3 (`tenancies (bed_id) WHERE status = 'active'`) is what actually *prevents* double-booking
— the view is just a read-time convenience, never the enforcement mechanism.

Likewise, `property_metrics` (occupancy %, rent collected/expected, open complaints per property) is
a **view**, computed from `rooms`/`beds`/`tenancies`/`rent_periods`/`payments`/`complaints` — the
exact same shape as the Flutter `propertyMetricsProvider` it's meant to eventually replace behind the
same repository interface, so nothing above the data layer needs to change when the swap happens.

The one thing the current mock has that a purely derived model doesn't: a `hold` state for
book-ahead reservations. **Not built in the current UI at all** (Phase 1 explicitly dropped
book-ahead in favor of the simple form — see `docs/DECISIONS.md`'s 2026-09-18 entry), so it's left
out of the initial schema entirely rather than added speculatively. Adding it later is cheap: it's
just one more `tenancies.status` value (`reserved`, say) that the occupancy view treats the same as
`active` for "not vacant" purposes — no structural change needed.

---

## 7. Financial model — deep dive

### `rent_periods` (what's owed)

One row per tenancy per month:

```
rent_periods
  id, tenancy_id, period_month (date, first-of-month), due_date,
  amount_due numeric(12,2), status (derived, see below), created_at
```

`amount_due` is a **snapshot** of `tenancies.rent_amount` at the time the period was generated —
so a mid-tenancy rent change only affects future periods, past ones keep what was actually agreed at
the time. Periods are generated by a scheduled function (monthly, per active tenancy) — not something
a client ever inserts directly.

### `payments` (what arrived)

```
payments
  id, rent_period_id, tenant_id (denormalized for query convenience, see §4),
  amount numeric(12,2), method (cash|upi|card|bank_transfer),
  recorded_by uuid references profiles,       -- who entered this: staff, or the tenant themself
  is_self_recorded boolean,                    -- true only for the tenant's own in-app payment
  status (awaiting_confirmation|paid|disputed),
  gateway_ref text,                             -- null for cash/staff-claimed; real ref once a gateway exists
  paid_at timestamptz, created_at timestamptz
```

**`payment_allocations`** (only needed once a single payment can cover more than one period — e.g. a
tenant pays two months at once, or a partial payment straddles a due-date boundary): a junction table
`payment_id, rent_period_id, amount_allocated`, `sum(amount_allocated) <= payments.amount` enforced by
a `CHECK`/trigger. **Recommendation: model the table now (cheap, a handful of columns) but don't
build any UI/RPC that produces multi-period allocations yet** — every current screen only ever
records a payment against exactly one period, so a payment's single-period case can insert one
allocation row 1:1 with itself, keeping today's behavior identical while the schema is already
capable of the harder case whenever partial/multi-period payments become a real feature. This is
the concrete answer to the mega-prompt's §9 requirement without over-building UI that has no current
demand.

### Payment state machine

Exactly the rule already correctly implemented in the mock and specifically confirmed by the product
owner earlier this session (the UPI/QR auto-mark-paid fix): **only a tenant's own verified in-app
payment settles instantly; every staff-claimed payment, regardless of method, is provisional.**

```
                    ┌─────────────┐
   (period created) │   pending   │
                    └──────┬──────┘
                           │ due_date passes, still unpaid
                           ▼
                    ┌─────────────┐
                    │   overdue   │
                    └──────┬──────┘
       staff records a payment (any method) ─┐
       from `pending` or `overdue`           │
                                              ▼
                                  ┌───────────────────────┐
                                  │ awaiting_confirmation  │
                                  └───┬───────────────┬────┘
                    tenant confirms   │               │ tenant disputes
                                      ▼               ▼
                                 ┌────────┐      ┌───────────┐
                                 │  paid  │      │ disputed  │
                                 └────────┘      └─────┬─────┘
                                                        │ (undesigned — see §12.6)
                                                        ▼
                                                   ??? resolution

   tenant's OWN in-app payment (recordSelfPayment):
   pending/overdue ──────────────────────────────────► paid   (direct, no confirmation step)

   `void_payment` (any of awaiting_confirmation/paid/disputed → back to pending/overdue,
   restores amount_due, clears method/paid_at) — an explicit correction action, not a delete.
```

| Transition | Who can trigger | RPC |
|---|---|---|
| `pending/overdue → awaiting_confirmation` | Owner or Manager assigned to the property | `record_payment(rent_period_id, method, amount, date)` |
| `pending/overdue → paid` (direct) | The tenant themself, only for their own period | `record_self_payment(rent_period_id, method, amount, date)` |
| `awaiting_confirmation → paid` | The tenant themself, only for their own payment | `confirm_payment(payment_id)` |
| `awaiting_confirmation → disputed` | The tenant themself, only for their own payment | `dispute_payment(payment_id)` |
| any → `pending/overdue` (void) | Owner or Manager assigned to the property | `void_payment(payment_id)` |
| `disputed → ?` | **Undesigned — see §12.6, flagged, not silently decided** | — |

Every transition is a Postgres function (`security definer`, checking the caller's role/scope
itself), not a raw client `UPDATE` — this is both the authorization boundary (a Manager can't collect
rent for a property they're not assigned to — checked inside the function, not just by RLS on a
read) and the business-validation boundary (can't confirm a payment that isn't `awaiting_confirmation`
in the first place) living in one place, per the mega-prompt's §18 distinction between authorization
and business validation.

### Complaint state (event-sourced on top of a cached current state)

```
complaints
  id, property_id, tenancy_id (nullable — common-area), category, severity, title,
  time_preference, reported_at, status (cached "current" — kept in sync by trigger),
  auto_resolve_days int default 3

complaint_events   -- append-only
  id, complaint_id, event_type (delegated|resolved|reopened|reassigned),
  actor_user_id, assignee text (nullable — only for delegated/reassigned),
  note text, created_at
```

`effective_status` is a function, exactly mirroring `Complaint.effectiveStatus` in Dart: if the
latest event is `delegated` and `now() - created_at >= auto_resolve_days`, effective status is
`resolved`; otherwise it's the latest event's resulting status. This fixes the mock's "delegation
overwrites history" gap (audit §backend-ui-data-audit.md cross-cutting observation #5) while keeping
the exact same time-derived-not-stored auto-resolve behavior the product already validated.

---

## 8. Tenancy model — deep dive

**Decision: adopt the identity/tenancy split** (`profiles`/`tenant_profiles` for who someone is,
`tenancies` for one stay), **simplified from the pre-pivot's 6-state model to match what's actually
built today.**

Pre-pivot states: `pending_approval, pending_profile, active, notice_period, moved_out, declined` —
designed for a flow (staff creates a skeletal record → tenant self-completes emergency
contact/ID/house-rules via a magic link → *then* becomes active) that **does not exist in any current
screen**. The audit confirms `completeInviteJoin` creates a tenant record and marks it `active`
*immediately* after just a name + phone OTP — no separate profile-completion step, no ID upload, no
house-rules acceptance anywhere in the app today.

**Proposed states for the real schema: `active`, `notice_period`, `moved_out`.** This matches
`TenantStatus` in the current Dart code exactly. The richer pre-pivot flow is not lost — it's a
strict superset reachable later by adding more `tenancies.status` values (`pending_approval`,
`pending_profile`) without touching any existing row or query, because every current write path
(`addTenant`, `assignPendingTenant`, `completeInviteJoin`) can simply keep inserting directly at
`active`, exactly as today, while a *future* richer path inserts at `pending_profile` instead — the
column already supports both, so this isn't a forward-incompatible simplification.

```
tenancies
  id, profile_id, bed_id,
  status (active|notice_period|moved_out) check,
  source (staff_created|self_joined) check,        -- was this via invite link or staff Add Tenant
  move_in_date date, move_out_date date,
  rent_amount numeric(12,2), rent_due_day smallint check (between 1 and 28),
  security_deposit_amount numeric(12,2),
  security_deposit_collected_at timestamptz,        -- nullable; not every deposit is collected via the payments ledger
  created_by uuid references profiles,               -- null if self-joined
  org_id uuid,                                        -- denormalized, see §4
  created_at timestamptz
```

**Bed history is automatic, not a separate table**: "which beds has this tenant ever had" is just
`select * from tenancies where profile_id = X order by move_in_date` — a person moving rooms within
the same PG, or to a different PG entirely (same or different org), is simply a new `tenancies` row
with the old one's `status` flipped to `moved_out`. No `tenant_bed_history` table needed; `tenancies`
*is* that history by construction, which is the entire point of not tying a tenant directly to a bed
column.

**The partial unique index (§3) is the actual anti-double-booking mechanism** — `move_in`/`move_out`
must happen as one transaction (`transfer_tenancy` RPC: closes the old tenancy, opens the new one,
both writes or neither) so a bed is never briefly claimable by two people mid-transfer.

---

## 9. RLS strategy

High-level matrix (full policy SQL is implementation, not this discovery doc — see §41 acceptance
criteria "RLS is enabled and tested" for the next phase). `S`=select, `I`=insert, `U`=update,
`D`=delete.

| Table | Owner | Manager (assigned properties only) | Tenant (own tenancy only) |
|---|---|---|---|
| `organizations` | S own org | — | — |
| `properties` | S/I/U own org's | S assigned only | — (discovery via a public view, if/when cross-owner browsing is adopted — §12.2) |
| `property_managers` | S/I/U/D own org's | S own assignment row only | — |
| `rooms`, `beds` | S/I/U own org's | S/I/U assigned properties' | S own tenancy's bed only |
| `tenancies` | S own org's; I/U via RPC only (see §7's authorization-in-function pattern) | S assigned properties'; I/U via RPC only | S own rows only; I via RPC only for the self-request path (§12.3, if adopted) |
| `rent_periods` | S own org's | S assigned properties' | S own tenancy's |
| `payments` | S own org's; write only via RPC | S assigned properties'; write only via RPC | S own tenancy's; write (confirm/dispute/self-pay) only via RPC |
| `complaints`, `complaint_events` | S own org's; write via RPC | S/write assigned properties' via RPC | S/write own tenancy's via RPC |
| `id_documents` | S own org's | S assigned properties' | S/I own tenancy's own documents |
| `tenant_invite_links` | S/I own org's | S/I assigned properties' | — (resolved server-side via service-role key before the tenant is authenticated, same as pre-pivot's reasoning) |
| `notifications` | S own | S own | S own |
| `audit_log` | S entries scoped to own org | S entries scoped to assigned properties (read-only, for accountability) | — |

**No table ever uses `USING (true)`.** Every policy resolves through the ownership chain in §4, via a
`security definer`, `stable` helper function (`auth_profile()`, same pattern as the pre-pivot schema)
so each policy is a single readable `exists(...)` clause, not a repeated 5-way join written out by
hand in every policy.

**Positive AND negative tests are required before this is considered done** (per §35/§41): a Manager
assigned to Property A must be proven unable to read/write Property B's rows, not just proven able to
read Property A's — the pre-pivot schema wrote good policies but this repo has no evidence any
negative case was ever actually tested against them.

---

## 10. Storage strategy

`id_documents` metadata lives in Postgres; the actual image/PDF lives in **Supabase Storage, a
private bucket** (never public). Column shape:

```
id_documents
  id, tenancy_id, document_type (id_front|id_back|photo|other),
  storage_path text,       -- bucket-relative path, not a public URL
  uploaded_by uuid references profiles,
  checked_by_staff boolean default false,
  superseded_by uuid references id_documents(id),   -- re-upload chain, see §5
  created_at timestamptz
```

Access is never a raw public URL — every read goes through a signed URL, generated server-side
(Edge Function or RPC) after the same RLS-equivalent check as the table row itself: an Owner reads
their org's documents, an assigned Manager reads their scoped properties' documents, a tenant reads
only their own. Storage bucket policies mirror the table's RLS logic rather than trusting "the bucket
is private" alone to be the only boundary — both layers enforce it independently, since Storage RLS
and table RLS are two separate systems that must agree, not one implying the other.

**Not built yet in the UI** (audit confirms `document_scan.dart` is an unrelated OCR-only
convenience, no photo is ever persisted today) — this section defines the shape so the eventual
upload screen has a real target, per the instruction not to make a clearly-planned future capability
(ID verification, `docs/DECISIONS.md`'s 2026-09-14 decision) harder to add later.

---

## 11. Transaction / RPC requirements

Operations identified as needing atomicity (all-or-nothing), each as a Postgres function rather than
several separate client writes:

| RPC | What it does atomically | Why it can't be 2+ client writes |
|---|---|---|
| `complete_invite_join(token, name, phone)` | Creates tenancy + profile (if new) + occupies bed + consumes invite token + (client then signs in) | Today's mock literally does these as 3 sequential separate calls (`addTenant`, `occupyBed`, `consumeInvite`) with no rollback — a failure between steps 1 and 2 today would leave a tenant record with no occupied bed. Real schema must not repeat this. |
| `transfer_tenancy(tenancy_id, new_bed_id, ...)` | Closes old tenancy (`moved_out`) + opens new tenancy on the new bed, in one transaction | Two tenants could otherwise both "win" a bed mid-transfer — exactly the race the pre-pivot schema flagged and never actually fixed |
| `record_payment(rent_period_id, method, amount, date)` | Validates caller is staff assigned to the property + inserts payment row at `awaiting_confirmation` + (future) fires a notification | Authorization + business rule + write, one unit — see §18 in the request, kept out of raw client `INSERT` |
| `record_self_payment(...)`, `confirm_payment(...)`, `dispute_payment(...)`, `void_payment(...)` | Same pattern — caller-role check baked into the function, not just RLS on the table | Same reasoning |
| `delegate_complaint(complaint_id, assignee, note)`, `resolve_complaint`, `reopen_complaint` | Inserts a `complaint_events` row + the trigger-maintained `complaints.status` cache stays consistent, one transaction | Prevents the "history overwritten" bug the current mock has |
| `generate_rent_periods()` | Scheduled (pg_cron or an Edge Function on a timer), not client-invoked — creates next month's `rent_periods` for every active tenancy whose period doesn't already exist | Idempotency matters here specifically — see §26 in the request on duplicate-operation safety; a re-run must not create a second period for the same tenancy/month (`unique (tenancy_id, period_month)`) |

**Idempotency, generally (§26 of the request):** payment recording and complaint creation are the two
places a flaky mobile network could plausibly cause a duplicate tap/retry. Recommendation: a
client-generated idempotency key (UUID, generated once per user action, resent on retry) on
`record_payment`/`record_self_payment`/`report_complaint`, with a short-lived unique constraint on
`(idempotency_key)` so a retried request is a no-op returning the original result rather than a
second row. This is cheap to add now and expensive to retrofit once real payment history exists —
worth building from day one even though it's a small addition, per the request's own §26 guidance to
identify (not necessarily fully build) idempotency-sensitive operations now.

**Deliberately NOT an RPC:** `add_room`, `add_property`, `add_tenant` (the simple, non-multi-step
cases) — plain `INSERT`s under RLS are sufficient; wrapping every CRUD operation in a function per the
request's own §36 warning against over-engineering ("do not create complicated RPCs for every CRUD
operation").

---

## 12. Ambiguities and decisions required before writing migrations

Per the instruction to stop and report rather than silently invent important business rules. Ordered
roughly by how much they'd cost to get wrong later.

### 12.1 Manager↔Property: is it really many-to-many, or is one-manager-per-property the real rule?
The current UI (`Property.managerName`) and every seeded mock property show **exactly one manager per
property** — `docs/domain-model-notes.md` says this explicitly ("design shows exactly one manager per
property, not many"). Nothing in the current app ever shows two managers on one property, or one
manager on two properties simultaneously (the Manager PG-switcher only ever *selects among* — it
doesn't imply multi-assignment is real, since there's no assignment concept at all right now).
**Proposal:** build `property_managers` as many-to-many at the DB layer (cheap, normalizes correctly,
matches the mega-prompt's explicit instruction to evaluate this rather than assume one FK) but have
Phase 6's actual UI/repository only ever exercise the single-manager case for now, with the real
constraint enforced in the product, not the schema. **This needs a yes/no from you**, specifically:
should the real product ever let one Manager cover multiple PGs (plausible — a small operator with 2-3
PGs might not hire a manager per property) or one PG have backup/co-managers? If genuinely never,
a simpler single `properties.manager_user_id` nullable FK is less schema than a join table for no
real benefit.

### 12.2 Cross-owner tenant identity — adopt the pre-pivot's biggest idea, or keep it simple?
The pre-pivot schema's most significant design decision (2026-09-15, "Cross-owner discovery +
identity/tenancy split") was built for a **platform-wide tenant discovery** product: a tenant browses
every owner's vacant beds, and the same person can have tenancies with *different* organizations over
their lifetime — hence identity (`profiles`/`tenant_profiles`) had to be split from tenancy in the
first place. **Nothing in the current Flutter app implements or even gestures at this** — there is no
"browse all PGs" screen, no public listing, no cross-owner anything; every tenant today reaches the
app via one specific invite link or is added directly by staff at one specific property. The proposal
above (§8) keeps the identity/tenancy *table* split (it's good normalization regardless, and costs
nothing extra even for a single-org tenant), but **does not build the public discovery views, the
tenant-requested self-registration insert policy, or any cross-owner browsing UI** — those stay
exactly as undesigned as they are today. **This needs a decision:** is cross-owner discovery still
the long-term vision (in which case the schema below is already correctly shaped for it, just not
wired to any UI yet), or has the product settled on "a tenant belongs to one owner's ecosystem,
reached via that owner's invite/staff flow only" (in which case the split is still fine, just
simpler than its original motivation)? Either answer is compatible with what's proposed — this
doesn't block writing migrations, but changes how much urgency the public-listing views deserve
later.

### 12.3 Tenant self-registration / "browse and request a bed"
Related to 12.2 but narrower: `PendingTenant` exists in the current mock, explicitly documented as
"the tenant-*requested* self-registration flow itself is explicitly not adopted yet" — every current
`PendingTenant` is seed data illustrating what the *assign* step looks like, never actually created by
a tenant action. **Proposal:** schema supports it (`tenancies.source = 'self_requested'`,
`status = 'pending_approval'`, per §8's extensible status column) but **no RPC/RLS insert policy for
a tenant to create their own pending tenancy is built in this milestone** — there's no screen that
would call it. Flagging so it's not silently forgotten, not silently built either.

### 12.4 Invite links: persisted rows, now — not deferred
Unlike 12.1-12.3, this one I'm treating as settled rather than open, because the current mock's
behavior is explicitly documented in its own code as a placeholder ("open question for DB phase" —
`docs/domain-model-notes.md` item 4) and the pre-pivot schema's answer (a real `tenant_invite_links`
table with `expires_at`/`used_at`) is strictly better with no real downside: it enables revoking a
leaked link, which a derived-from-string token can never support. **Proceeding with persisted invite
links** unless you object.

### 12.5 ID-document verification — build the schema, still no UI
Settled the same way: `docs/design-readme-reconciliation.md` flagged this as needing a decision
("was this deliberately deferred past this screen set, or does a screen still need to be designed").
Nothing has resolved it since. **Proposal: schema + storage bucket exist (§10), no upload screen is
built this milestone** — this is the safest default (doesn't block the backend work, doesn't
preemptively build a screen nobody's asked for) and is explicitly reversible either direction later.
Flagging, not deciding on your behalf, whether the *screen* should exist.

### 12.6 Who resolves a disputed payment, and how?
Genuinely undesigned **in the UI itself**, not just in the schema — audited directly: no screen (Owner,
Manager, or Tenant) shows any action available on a `disputed` payment. The state machine in §7 has
literal `???` at that node. **This blocks writing a complete `payment_state_machine.md` later, and
ideally should be answered before real Owners hit a real dispute** — but since building the schema
itself doesn't require deciding this (an `Owner`-only `void_payment`/re-record escape hatch already
technically exists and works as a manual resolution, just with no dedicated "resolve this dispute" UI
framing it that way), **this does not block migrations**, only the completeness of the eventual UI
work. Recommend: an Owner can void a disputed payment (puts it back to pending/overdue) as the interim
answer, using the RPC that already needs to exist anyway.

### 12.7 `super_admin` role
Pre-pivot schema includes it (internal/support use, no end-user UI, already confirmed "no conflict"
in `docs/design-readme-reconciliation.md` §2). Current `UserRole` Dart enum omits it entirely (only
owner/manager/tenant). **Proposal: omit from the `profiles.role` CHECK constraint for this
milestone** — adding a 4th allowed value later is a one-line migration with zero data impact, and
building it in now with no UI or use case violates the request's own §36 anti-overengineering
guidance. Flagging only so its absence is a decision, not an oversight.

### 12.8 Room number / bed label uniqueness scope
`docs/design-readme-reconciliation.md`/`domain-model-notes.md` never answered "can two rooms share a
number on different floors" or "can two beds share a label in different rooms" — and the current mock
enforces neither. Seeded data never collides, but that's not evidence of a rule. **Proposal:
`unique (property_id, room_number)` and `unique (room_id, bed_label)`** — i.e. a room number is unique
across the whole property regardless of floor (matches how Owner/Manager Rooms screens already treat
room number as a property-wide human search key, not a floor-scoped one), and a bed label is unique
within its room only (A/B/C per room, freely reused across rooms — exactly what's seeded). Reasonable
default, not something the current code actually decides either way — flagging in case a real
property's numbering scheme (e.g. "101" on floor 1 and "101" on floor 2, genuinely) needs the looser
rule instead.

### 12.9 Occupancy trend history (Reports screen)
The 6-month occupancy trend chart currently shows **hardcoded illustrative percentages** — there is no
real historical occupancy data anywhere to compute this honestly, mock or otherwise. Two real options:
(a) a daily/monthly scheduled snapshot job writing to a small `occupancy_snapshots` table (property_id,
snapshot_date, occupied_beds, total_beds), or (b) derive retroactively from `tenancies.move_in_date`/
`move_out_date` at query time once enough tenancy history exists (works immediately for *future*
months, can't reconstruct *past* months before the backend existed). **Not blocking this milestone**
(Reports isn't part of the core invariant/ownership/RLS work) but flagging since it's a real gap the
audit surfaced that neither the current code nor any doc has an answer for. Lean toward (a) — cheap,
gives exact history going forward — decide when Reports gets its real backend wiring.

---

## 13. What this milestone will NOT do (explicitly, per §37 phase boundaries)

No payment gateway integration (Razorpay etc. — `.env.example` already notes this is a later phase),
no WhatsApp/SMS sending infrastructure, no analytics platform, no AI features, no offline sync beyond
what Riverpod's own caching already gives for free, no super-admin UI, no accounting/tax engine. The
schema is shaped so none of these are made *harder* later (rent_periods/payments already support a
future `gateway_ref`; notifications table is channel-agnostic; audit_log exists before anything
seriously needs auditing) — but none of them are built now.

---

## 14. Decisions (resolved 2026-09-22)

1. **§12.1 Manager↔Property — many-to-many, confirmed.** `property_managers` is a real join table,
   not a single FK. Built as designed in §1-2.
2. **§12.2 Cross-owner tenant identity — adopt the schema split now, build no marketplace UI.**
   Product context: a public PG-discovery marketplace is a real future direction, but it will ship as
   **a separate companion web app on this same Supabase/Postgres backend** (public, SEO-indexable,
   no-install browsing for prospective tenants), not as a second mobile app and not as a feature
   inside the current Flutter ops app. The Flutter app stays the single place a tenant does anything
   once they have — or are getting — an account (browsing *or* managing an active stay); the web
   surface only exists to be found by search engines and hand off into that same account system. This
   is why the identity/tenancy split is adopted now — a tenant has to exist as a person independent of
   any one owner *before* they've chosen one, which is exactly the marketplace's precondition — while
   the actual marketplace feature set (public listings, search, photos, inquiries/leads, moderation)
   is explicitly **not** part of this backend milestone. Revisit as its own design pass when that
   work starts; nothing in the schema below blocks it.
3. **§12.6 Disputed payments — Owner-only override, either direction, with a required note.** A
   Manager can see a disputed payment on their assigned property but cannot resolve it themselves
   (conflict of interest — they're the one whose claim is in question). Only the Owner can call
   `resolve_dispute(payment_id, outcome, note)` where `outcome` is `paid` (staff was right, tenant's
   dispute is overruled) or `voided` (staff was wrong, back to pending/overdue) — `note` is required
   in both directions so there's a record of why. This supersedes the plain `void_payment` escape
   hatch as the sanctioned way to close out a `disputed` payment specifically (void_payment on its own
   still exists for the simpler "staff made an honest mistake before any dispute" case).

Proceeding to schema/migrations now. Everything else in §12 (12.3-12.5, 12.7-12.9) proceeds with the
stated default.
