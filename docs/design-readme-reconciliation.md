# README ↔ Design reconciliation

> **Note (Flutter pivot):** written while the app was still assumed to be Next.js/web. The platform
> changed to Flutter mobile shortly after this doc was written, but nothing below is platform-specific
> — it's entirely about product scope (README vs. design), not tech stack. Still fully valid; no
> rework needed.

Written when the "PG Khata product design" handoff (18 screens, `design_handoff_pg_khata_app/`) was
received and compared against the README/product plan and `supabase/schema.sql` as they stood at the
end of Phase 0. This is a point-in-time reconciliation, not a living doc — once a decision below is
made, it should move into `DECISIONS.md` and this file's entry should be marked resolved, not deleted.

Source of truth used: the actual `.dc.html` screens and their inline mock-data script blocks, **not**
the design package's own README summary (read both, but where they'd disagree the screens win).

## 1. Features in both README and design

| Feature | README | Design |
|---|---|---|
| Phone OTP auth | Planned, built in Phase 0 | `Auth.dc.html` |
| Role-based Owner/Manager/Tenant dashboards | Planned | All three role screen sets |
| Cash + digital rent payments | Planned (Phase 3) | `Manager Payments`, `Tenant Payments`, `Owner Payments` |
| Complaints | Planned (Phase 5) | `Manager Complaints`, `Tenant Complaints` |
| Multi-property Owner portfolio | Implied by `organizations`/`properties` schema | `Properties`, `PortfolioSwitcher` |
| Manager "Today" stat row feeding a future WhatsApp digest | Explicitly decided in DECISIONS.md (2026-09-14) | `Manager Today.dc.html` — same four numbers |

## 2. Features in README but missing from design ⚠️

### ⚠️ ID-photo tenant verification
**README/DECISIONS says:** Phase 0-2 stores a plain uploaded ID photo (`id_documents` table) with a
manual "checked by staff" toggle — a deliberate, decided replacement for Aadhaar e-KYC.
**Design contains:** No upload flow, no review screen, no mention in any of the 18 screens (checked
Auth, Settings, and every Tenant/Owner/Manager screen).
**Status:** Needs a product decision — was this deliberately deferred past this screen set, or does a
screen still need to be designed before it's implemented? Do not build a guessed-at UI for this.

### ⚠️ WhatsApp daily digest as a feature surface
**README/DECISIONS says:** Phase 4 adds a Manager-facing WhatsApp digest; the Phase 0 "Today" screen
exists specifically to share its query shape with the digest job.
**Design contains:** The Manager Today stats exist and match, but there's no digest preview, opt-in
toggle, or "sent" confirmation screen — only the underlying numbers.
**Status:** Not a conflict, just incomplete relative to the original plan — the digest itself is still
a backend job for a later phase, per the original decision. No action needed now.

### ⚠️ `super_admin` role
**README/schema says:** `profiles.role` includes `super_admin` for internal/support use, no end-user UI.
**Design contains:** No fourth role anywhere.
**Status:** Consistent — README already said this role has no Phase-0-era UI. No conflict.

### ⚠️ Backlog ideas (WhatsApp receipts, owner weekly digest, manager nudge, magic-link tenant view, digital move-in acknowledgment, offline-queue indicator)
**Status:** Correctly absent from design — DECISIONS.md explicitly lists these as "not scheduled yet."
No conflict.

## 3. Features in design but missing/under-documented in README ⚠️

### ⚠️ Complaint lifecycle — completely redesigned (highest priority to resolve)
**README/schema says:** `complaints.status` is `open | in_progress | resolved`, with a raw
`assigned_to uuid references auth.users`.
**Design contains:** A different lifecycle — `Reported → Delegated → Resolved` (or `Reopened`) — where
the Manager's only required action is "Delegate & done" (pick Self/Cleaner/Electrician/Plumber/Outside
vendor + optional note). The ticket **auto-resolves after 3 days** unless the tenant reopens it. This
is computed **client-side** in the prototype (`effectiveStatus()` in `Manager Complaints.dc.html` and
`Tenant Complaints.dc.html`) — the design's own README flags this as a placeholder that "should be a
scheduled/derived server-side status" in production.
**What's different:** The whole approval/dropdown model is gone. Assignees are not necessarily real
user accounts ("Cleaner", "Plumber", "Outside vendor" are role labels, not people with logins).
Complaints also gained fields the schema doesn't have: `priority` (Low/Medium/High), a tenant-set
`timePref`, and a `note` on delegation.
**Decision required:** Adopt this as the real production model? If yes: is "assignee" a free-text
label, a fixed enum, or a future real vendor-contact entity? Is the 3-day window configurable per
property/org? Who can act on a `Reopened` ticket?

### ⚠️ Cash-payment confirm/dispute loop
**README/schema says:** `payments.status` is `paid | due | overdue | partial`. No confirmation step.
**Design contains:** A Manager recording a cash payment sets it to **"Awaiting confirmation"** until
the Tenant taps Confirm or "I didn't pay this" (→ **Disputed**). See `Manager Payments.dc.html`'s
"Collect rent" dialog and `Tenant Payments.dc.html`'s confirm/dispute card.
**Decision required:** Adopt as the real flow? Needs two new status values and a decision on who
resolves a `Disputed` payment and how (currently undesigned past the dispute tap itself).

### ⚠️ Self-registration + invite links (biggest scope/security change)
**README says:** "An Owner/Manager creation UI is a Phase 1 feature" — for now, rows are inserted
manually in the Supabase Table Editor. No self-serve signup at all.
**Design contains:** `Auth.dc.html` lets anyone sign up, **pick their own role** (Owner/Manager/Tenant),
and join a PG either by typing a property/room code or via a bed-specific invite link
(`Auth.dc.html?invite=hsr-101-A`) generated from `Manager Rooms.dc.html`'s "Invite via link" action
(copy link or share to WhatsApp). A tenant with no code still gets created, pending an Owner/Manager
assigning them a bed (`Owner Tenants.dc.html` / `Manager Tenants.dc.html`'s "Self-registered — needs a
bed" section).
**Decision required:** This is a real trust-boundary question, not a cosmetic one — should signup let
someone self-select "Owner," or should Owner accounts still be provisioned out-of-band? What validates
that a join-code/invite-link actually grants membership in the right org?

### ⚠️ Reports screen
**README says:** Not mentioned anywhere in the roadmap or Phase descriptions.
**Design contains:** `Reports.dc.html` — revenue-by-property bars, a 6-month occupancy trend chart, and
a property comparison list, reachable from the Owner Dashboard's quick actions.
**Decision required:** Confirm this is in scope, and whether it needs a real charting library or the
design's hand-rolled `<div>` bar charts are an acceptable production pattern.

### ⚠️ Floor as a grouping — and no "Building" level at all
Your own conceptual hierarchy (Owner → Property → Building → Floor → Room → Bed → Tenant) includes a
Building level. **No screen has one.** Rooms are grouped by a free-text "Floor" label (e.g. "Ground
Floor", "First Floor") directly under Property in `Owner Rooms.dc.html` / `Manager Rooms.dc.html`'s
"Add Room" dialog — Floor is a text field on the room form, not a managed entity with its own CRUD,
ordering, or floor-level attributes.
**Decision required:** Is "Building" ever going to be a real level (needed for owners with genuinely
multi-building properties), or is Property the top physical unit with Floor as a lightweight label —
matching what's actually designed? Recommend matching the design (no Building entity) unless you know
of a real property in scope that needs it.

### ⚠️ Move-out — partially designed, contradicting its own backlog listing
DECISIONS.md lists "Move-out / security-deposit settlement flow" under **backlog, not scheduled**. The
design already fully implements a simple version — Owner/Manager can mark a tenant "moved out," which
frees the bed and sets status to "Vacated" (`Owner Tenants.dc.html`, `Manager Tenants.dc.html`). What's
still undesigned is the **deposit-settlement** part the backlog note called out as the actually
dispute-prone piece.
**Status:** Treat the simple free-the-bed move-out as newly in-scope (it's fully designed); the deposit
settlement flow remains genuinely deferred.

### ⚠️ PG announcements
Entirely new: a broadcast banner on `Tenant Home.dc.html` ("Water supply will be interrupted...").
No entity, no authoring UI shown (no screen for an Owner/Manager to write an announcement) — only the
tenant-facing display exists.
**Decision required:** In scope now? If yes, an authoring flow needs to be designed — it doesn't exist
yet even in the design package.

### ⚠️ Settings — notification preferences & language
No Settings screen exists in the current codebase at all. The design's `Settings.dc.html` adds: a
mandatory "Rent reminders" toggle (always on), optional Complaint-updates/PG-announcement toggles, and
an 8-language selector (English/Hindi/Hinglish/Kannada/Tamil/Telugu/Marathi/Bengali).
**Status:** New scope, not a conflict — just undocumented. No open product question, straightforward
to build.

### ⚠️ Navigation structure changed
Current `NAV_ITEMS` (`src/lib/constants.ts`) doesn't match the design:
- Manager: current = Today/Tenants/Payments/Complaints (4 flat tabs). Design = Today/Payments/Rooms/**More**
  (More → Tenants, Complaints, Settings). Current nav is **missing a Rooms tab entirely**.
- Owner: current = Dashboard/Properties/Tenants/**Collections**. Design = Overview/Properties/Tenants/**More**
  (Reports and Payments reached via quick-action tiles on the dashboard, not bottom-nav tabs).
**Status:** Not a product decision, just an implementation update — align `NAV_ITEMS` to the design.

### ⚠️ RoleSwitcher.dc.html
The design package's own README flags this: "likely a prototyping aid only — confirm whether real
users ever switch roles in one session or whether this is strictly per-account." Repeating that flag
here rather than silently deciding either way.
**Decision required:** Ship it (useful if one person can genuinely hold multiple roles, e.g. an Owner
who also manages a property day-to-day) or treat it as a dev/demo-only tool that never reaches
production, same as `dev-bypass.ts`.

## 4. Scope changes summary

| Feature | Change |
|---|---|
| Complaints | Full lifecycle redesign (dropdown-status model → delegate/auto-resolve model) |
| Payments | Added confirm/dispute sub-flow for cash |
| Onboarding | Owner-provisioned-only → self-registration + invite links |
| Move-out | Backlog/unscheduled → basic version now designed (settlement part still deferred) |

## 5. Intentionally deferred (confirmed still out of scope)

- Aadhaar Paperless Offline e-KYC (per the original 2026-09-14 decision — unaffected by this design pass)
- Deposit settlement math (only the "free the bed" half of move-out is designed)
- WhatsApp receipt-per-payment, Owner weekly digest, Manager nudge, magic-link tenant view, digital
  move-in acknowledgment, offline-queue indicator (all backlog, unscheduled)
- Super Admin UI

## 6. Decisions required from the product owner

1. Adopt the new complaint delegate/auto-resolve model as production behavior? (assignee shape, timer
   configurability, reopen handling)
2. Adopt the cash-payment confirm/dispute loop? (dispute-resolution path is undesigned)
3. Allow self-registration with self-selected role, or keep Owner-provisioned accounts only?
4. Is "Building" ever a real entity, or does Property → Floor (label) → Room → Bed match reality?
5. Is ID-photo verification still wanted, and if so does it need its own screen designed?
6. Is Reports in scope for the next build phase?
7. Ship RoleSwitcher to production, or dev/demo-only like `dev-bypass.ts`?
8. Keep a responsive desktop layout (current `NavSidebar`), or match the design's mobile-only shell
   exactly and treat desktop as unsupported for this app?
9. PG announcements — in scope now (needs an authoring UI not yet designed) or deferred?
