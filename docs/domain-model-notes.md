# Domain model notes (frontend discovery pass — not a schema)

> **Note (Flutter pivot):** the entities/relationships below were discovered while implementing the
> design against a TypeScript mock layer (since discarded along with the Next.js app — see
> `DECISIONS.md`). The discoveries themselves are platform-agnostic and still fully valid; they'll be
> re-expressed as Dart classes in `mobile/lib/features/*/domain/` instead of `src/types/domain.ts`.

Written while implementing the approved UI design against mock data. Captures the entities and
relationships the *design* actually requires, discovered screen-by-screen. **This is not a database
schema** — no tables, keys, or constraints are decided here. `supabase/schema.sql` is Phase 0's
schema for an older domain model (see `docs/design-readme-reconciliation.md` §3-4 for what changed)
and is left untouched until the database phase deliberately redesigns it.

Frontend TypeScript domain types (in `src/types/domain.ts` once written) are allowed to diverge from
whatever the eventual database shape turns out to be — that's expected, not a bug, per the ground
rules for this phase.

## Entities discovered

- **Profile** — a person: role (`owner | manager | tenant`), name, phone. A manager or tenant may
  exist *unassigned* (self-registered, no property/bed yet) — see `Owner Tenants.dc.html`'s
  "Self-registered — needs a bed" section. This pending state is a real, designed state, not an edge
  case to special-case away.
- **Property** — a single PG. Has an address, a total bed count, one assigned Manager (design shows
  exactly one manager per property, not many).
- **Floor** — a free-text label grouping Rooms within a Property (e.g. "Ground Floor"). Not shown as
  an independently manageable entity anywhere (no floor list, no floor edit/delete). Treated as a
  string field on Room for now — see open question below.
- **Room** — belongs to a Property (via Floor grouping), has a room number, a sharing type
  (Single/Double/Triple/Four sharing — this determines bed count: 1/2/3/4), and a rent-per-bed amount.
- **Bed** — belongs to a Room, has a label (A/B/C...), and is either vacant or occupied by exactly one
  Tenant. A vacant bed has two distinct onboarding actions available: "Assign existing" (pick from
  already-registered tenants) or "Invite via link" (generate a bed-specific invite URL).
- **Tenant** — a Profile once assigned to a Bed. Has monthly rent, a join date, and a status
  (`Active | Notice period | Vacated`). Vacating a tenant frees their bed.
- **InviteLink** — ephemeral, bed-specific (`propertyId-roomNumber-bedLabel`), generated on demand by
  a Manager, not persisted as its own record in any screen (built from the current bed's identity each
  time "Invite via link" is clicked). Whether this needs to be a real stored/expiring entity (vs.
  always-derivable from the bed's identity) is an open question for the DB phase.
- **JoinCode** — a property-level code a self-registering Manager or Tenant can type in during signup
  (`Auth.dc.html`'s "PG / property code"). Format and lifecycle (per-property static code? rotating?)
  is not shown in the design — only the input field exists.
- **Payment** — belongs to a Tenant, has an amount, a method (Cash/UPI/Bank Transfer), a due date, and
  a status. Cash payments carry an extra sub-state: `Awaiting confirmation` (Manager recorded it,
  Tenant hasn't responded) → `Paid` (Tenant confirmed) or `Disputed` (Tenant said they didn't pay).
  Digital payments (UPI/Bank Transfer) appear to go straight to `Paid` in the design (no gateway
  integration shown — recorded as already-settled, consistent with the existing schema's note that
  "no money ever moves through the app itself").
- **Complaint** — belongs to a Tenant and a Property, has a category (Plumbing/Electrical/
  Wifi-Internet/Cleaning/Other — auto-detected from title text in the Manager view, explicitly chosen
  by the Tenant in the report form), a priority (Low/Medium/High), a preferred time-to-fix, and a
  status lifecycle: `Reported → Delegated → Resolved` (or `Reopened` from Resolved/Delegated if the
  tenant says it's not fixed). A Delegated complaint carries an assignee (see below), a delegation
  timestamp, an optional note, and an auto-resolve window (3 days in the design, hardcoded).
- **ComplaintAssignee** — **not necessarily a Profile.** The options are "Self (I'll fix it)",
  "Cleaner", "Electrician", "Plumber", "Outside vendor" — role labels a Manager picks, not accounts
  with logins. Whether any of these ever need to be real contactable entities (e.g. a saved vendor
  phone number) is undesigned.
- **Announcement** — a short text broadcast shown on Tenant Home. No authoring screen exists anywhere
  in the 18 screens — only the tenant-facing display. Author, scope (per-property? per-org?), and
  expiry are all undesigned.
- **NotificationPreference** — per-profile: rent reminders (mandatory, always on), complaint updates
  (optional toggle), PG announcements (optional toggle).

## Relationships as designed

```
Owner (Profile, role=owner)
  └─ owns many Properties
       ├─ has one assigned Manager (Profile, role=manager)
       ├─ has many Rooms (grouped by a free-text Floor label)
       │     └─ has many Beds (count fixed by sharing type)
       │           └─ optionally occupied by one Tenant (Profile, role=tenant)
       ├─ has many Complaints (via its Tenants)
       └─ has many Payments (via its Tenants)

Tenant
  └─ has many Payments (one expected per period_month, cash ones carry a confirm/dispute sub-state)
  └─ has many Complaints (each optionally Delegated to a ComplaintAssignee, which may not be a Profile)
```

No "Building" level appears anywhere — see the reconciliation doc's open question #4. Treating Property
as the top physical unit (no Building) unless told otherwise.

## Open questions for the eventual database phase

These are discoveries, not decisions — do not resolve them by picking an implementation now.

1. **Floor** — promote to a real entity (own table, ordering, floor-level attributes) or keep as a
   free-text label on Room, matching exactly what's designed today?
2. **Building** — ever real, or is Property → Floor(label) → Room → Bed the actual physical hierarchy?
3. **ComplaintAssignee** — free-text enum forever, or eventually a real "vendor contacts" entity per
   property (so "Plumber" resolves to an actual phone number instead of a label)?
4. **InviteLink / JoinCode** — derived-on-demand strings (as the prototype does) or persisted rows with
   their own expiry/usage-tracking (needed if you ever want to revoke a leaked invite link)?
5. **Payment confirm loop** — who can resolve a `Disputed` payment, and how (undesigned past the
   tenant's dispute tap)?
6. **Self-registration trust boundary** — does a join-code alone grant org/property membership, or does
   an Owner have to approve a self-registered signup before it's real (today, "pending" tenants already
   show up in lists before anyone approves them — is that intentional)?
7. **Auto-resolve window** — 3 days is hardcoded in the prototype; per-org/property configurable later?
8. **Announcement** authorship, scope, and expiry are all unspecified — needs its own design pass
   before it can be modeled, let alone built.

None of these block frontend implementation against mock data — they only matter once the database is
deliberately designed, per the instruction not to let a UI shape dictate the production schema.
