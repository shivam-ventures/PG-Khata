# PG Khata

Rent, rooms and tenants — without the register. A mobile-first app for
managing paying-guest (PG) accommodations, with three roles: **Owner**
(portfolio-level oversight across properties), **Manager** (day-to-day
operations at one or more PGs), and **Tenant** (self-service for the
resident).

## Where the product stands

| Phase | Status |
|---|---|
| Phase 0 — foundation (design tokens, OTP auth, empty dashboards) | ✅ Implemented |
| Design — full-app UI design for Owner/Manager/Tenant | ✅ Complete (approved, 18 screens) |
| Application development — production UI against the approved design | 🚧 In progress |
| Database — real schema, RLS, backend integration | ⏳ Deliberately not started |

The current codebase is Phase 0 plus a design-implementation pass in progress. **Nothing described
under "Designed flows" below is wired to real data yet** — it's being built against a mock-data layer
first; see `docs/domain-model-notes.md` for why the database comes last, not first.

## What's actually implemented in code right now

- Next.js (App Router) + TypeScript + Tailwind, design tokens for light/dark mode
  (`src/app/globals.css`, `tailwind.config.ts`)
- Reusable component library (`src/components/ui/`) — see `docs/DESIGN_SYSTEM.md`
- Phone-number OTP login via Supabase Auth (`src/features/auth/`) — the basic phone→OTP happy path
  only; the richer signup flow described below (role picker, self-registration, invite links) is
  designed but not yet built
- Role-based routing with Row Level Security as the real permission boundary
  (`supabase/schema.sql`, `src/lib/auth.ts`, `src/middleware.ts`) — schema reflects the **old**
  payment/complaint model; see the reconciliation doc below before extending it
- Empty-state Owner / Manager / Tenant dashboards (being replaced screen-by-screen with the approved
  design)

## Completed design scope (approved, being implemented)

A full 18-screen design handoff exists for every role. Source screens (self-contained HTML
prototypes, not production code) plus the design system are archived for reference; the production
build recreates them in React/Tailwind using this codebase's own component patterns.

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

Old model (superseded): tenant reports → manager sets status via dropdown → tenant confirms fixed.
**New model:** `Reported → Delegated → Resolved` (or `Reopened`). A Manager's only required action is
**"Delegate & done"** — pick who's handling it (Self/Cleaner/Electrician/Plumber/Outside vendor) +
an optional note, one tap. A delegated ticket **auto-resolves after 3 days** unless the tenant says
it's still not fixed. No forced manager follow-up, no tenant "confirm fixed" tap required. This
replaces the `open/in_progress/resolved` enum in the current schema — see
`docs/design-readme-reconciliation.md` before building against the old schema.

### Payments — cash confirm/dispute loop

A Manager recording a cash payment sets it to **"Awaiting confirmation"**; the Tenant then confirms
it or disputes it ("I didn't pay this") rather than the Manager's word being final. Digital payments
(UPI/Bank Transfer) go straight to Paid. This adds status values the current schema doesn't have.

### Onboarding — self-registration + invite links (new, not yet decided)

The design adds self-serve signup (pick your own role, join via a property code) and bed-specific
invite links a Manager can copy or share on WhatsApp. This is a real scope and trust-boundary change
from "Owner/Manager creation is a Phase 1 feature, insert rows manually for now" — **flagged as a
decision required, not yet adopted** (see the reconciliation doc).

## Known design/product gaps

Full detail in [`docs/design-readme-reconciliation.md`](docs/design-readme-reconciliation.md) —
what's in the README but not designed (ID-photo verification, the WhatsApp digest as its own screen),
what's designed but wasn't in the original plan (Reports, the redesigned complaint/payment models,
self-registration, PG announcements, no "Building" entity despite the conceptual hierarchy mentioning
one), and the specific product decisions still needed before some of this becomes real behavior
instead of just an approved design.

Domain entities and relationships discovered while implementing against the design (not a database
schema — that comes later, deliberately) are in
[`docs/domain-model-notes.md`](docs/domain-model-notes.md).

## Feature roadmap (phase-wise, superseded/refined by the design pass above)

1. **Phase 0** ✅ — design system, OTP auth, empty dashboards (this repo's starting point)
2. **Application development** 🚧 — recreate the approved design against mock data: Owner flows →
   Manager flows → Tenant flows → cross-cutting states (loading/empty/error/responsive/a11y)
3. **Database** ⏳ — deliberate domain modeling and schema design, informed by
   `docs/domain-model-notes.md` and the decisions in the reconciliation doc — not started, and not
   dictated by frontend types or an ORM
4. **Backend integration + RLS** ⏳ — wire the mock-data layer over to Supabase without rewriting UI
5. **Reminders** ⏳ — Tenant rent reminders + Manager WhatsApp daily digest (the Manager "Today"
   stats already match the digest's shape by design)
6. Deferred/backlog: Aadhaar-alternative e-KYC upgrade path, deposit-settlement move-out flow,
   WhatsApp payment receipts, Owner weekly digest, Manager nudge, magic-link tenant view — see
   `docs/DECISIONS.md`

## Important product decisions

See `docs/DECISIONS.md` for the running log (ID-photo storage instead of Aadhaar e-KYC, Manager
WhatsApp digest scope, the dev-only auth bypass) and
`docs/design-readme-reconciliation.md` §6 for decisions raised by the design pass that are still
open (complaint/payment model adoption, self-registration trust model, Building-as-entity, Reports
scope, RoleSwitcher production status, desktop layout support).

## Fastest way to just look at it (no Supabase setup)

```bash
npm install
cp .env.example .env.local
```

Open `.env.local` and uncomment `NEXT_PUBLIC_DEV_BYPASS_AUTH=true`, then:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) — you'll land on a role
picker instead of the login screen, and can click straight into the Owner,
Manager or Tenant dashboards. A "Dev preview mode" banner stays on screen
the whole time so it's never mistaken for the real thing. This bypasses
real auth entirely — see `src/lib/dev-bypass.ts`. Do the real setup below
whenever you're ready to sign in for real.

## First-time setup (real auth)

**1. Install Node.js 20+** if you don't already have it — check with
`node -v` in Terminal. If that command isn't found, install it from
[nodejs.org](https://nodejs.org) (the LTS version) and reopen Terminal.

**2. Install dependencies** — from this folder:

```bash
npm install
```

**3. Create a Supabase project** — free tier is enough for now, at
[supabase.com](https://supabase.com/dashboard). Once created:

- Go to **Project Settings → API** and copy the **Project URL** and
  **anon public key**.
- Go to **Authentication → Providers → Phone**, enable phone sign-in, and
  either add a line under **Test OTPs** (e.g. `+919999999999=123456` — sign
  in with that exact number + code, no SMS account needed, dev-only) or
  configure a real SMS provider (MSG91 or Twilio — a real per-SMS cost once
  you're sending live OTPs to real people).
- Go to the **SQL Editor**, paste the contents of `supabase/schema.sql`,
  and run it — this creates every table and the Row Level Security
  policies that keep a Manager from ever seeing another owner's data. Note:
  this schema reflects the pre-design-pass domain model (see the
  reconciliation doc) and will need deliberate revision once the database
  phase starts.

**4. Add your environment variables:**

```bash
cp .env.example .env.local
```

Open `.env.local` and paste in the Project URL and anon key from step 3.

**5. Run it:**

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) — it redirects to
`/login`. To actually sign in, you'll need at least one row in the
`profiles` table matching a real phone number you can receive an SMS on
(insert one manually in the Supabase Table Editor for now — a real
Owner/Manager creation UI is still pending the self-registration decision
above).

## Project structure

See `docs/DESIGN_SYSTEM.md` for the component library. Short version:

```
src/app/            Next.js routes, grouped by role: (auth) (owner) (manager) (tenant)
src/components/ui/   Design-system primitives (Button, Card, Input, ...)
src/components/      Domain components built from those primitives
src/features/        Feature code — components/hooks/services per feature
src/services/        External API clients (Supabase) + the mock-data layer during this phase
src/lib/             Cross-cutting helpers (utils, constants, auth guard)
src/hooks/           Cross-feature React hooks
src/types/           Shared TypeScript types, incl. domain types (not database types)
supabase/schema.sql  Database schema + Row Level Security policies (pre-design-pass model)
docs/                Decisions log, design system reference, design/README reconciliation,
                     domain model discovery notes
```

## Scripts

- `npm run dev` — local dev server
- `npm run build` — production build
- `npm run lint` — ESLint
- `npm run typecheck` — TypeScript, no emit
