# Architecture — Flutter mobile app

Written at the Next.js → Flutter pivot. Describes the proposed structure for `mobile/` (created once
the Flutter SDK is installed — see the environment audit in `DECISIONS.md`'s pivot entry). This is a
proposal to build against, not poured concrete — revise it if implementation reveals a better shape,
but document why, here or in `DECISIONS.md`.

## Why Flutter over React Native (recap of the decision)

1. **Runnable in this environment with the least friction.** Neither Flutter nor bare React Native
   can be compiled/simulated on this machine today (no Xcode, no Android SDK) — but this was the
   user's explicit platform choice regardless, made with that constraint already known.
2. Flutter draws its own UI (Skia) rather than wrapping native components, which suits a design system
   with specific, exact spacing/radius/color tokens ("Modernist" + the v2 layer) that must render
   identically on iOS and Android without two native styling systems to keep in sync.
3. Single language (Dart) for the whole client, single team skill to maintain.

## Project structure

```
mobile/
  lib/
    core/
      theme/          # ColorScheme, TextTheme, spacing/radius constants — derived from
                       # design/design_handoff_pg_khata_app/screens/_ds/*/styles.css and
                       # tokens-extra.css. One source of truth; screens never hardcode a color.
      routing/         # go_router configuration, one route table per role
      constants/       # enums mirrored from src/types (ported to Dart), nav item definitions
      utils/           # formatters (currency, relative time — ports of the old formatINR etc.)
      errors/          # typed failure/result types for repository calls
    features/
      auth/
        presentation/  # screens + widgets (phone entry, OTP, role picker, invite/join)
        application/   # state (see "State management" below) — sendOtp/verifyOtp/etc as intents
        data/           # AuthRepository — mock implementation now, Supabase later
        domain/         # Profile, Role — ported from src/types/domain.ts
      properties/       # Owner: portfolio list, add/edit property
      rooms/             # Owner + Manager: room/bed occupancy, add room, invite-via-link
      tenants/            # Owner + Manager: roster, add/assign, move-out
      payments/            # Owner + Manager + Tenant: ledger, collect, confirm/dispute cash
      complaints/           # Manager + Tenant: report, delegate-and-done, auto-resolve display
      dashboard/             # Owner Dashboard, Manager Today, Tenant Home — role-specific home screens
      reports/                # Owner Reports
      settings/                # shared Settings (profile, notification prefs, language)
      notifications/            # in-app notification/announcement display (no push infra yet — §32)
    shared/
      widgets/          # StatusChip, StatCard, EmptyState, AppBottomNav, PortfolioSwitcher —
                         # cross-feature UI ported from the old src/components/ equivalents
      models/            # cross-feature model helpers not owned by one feature
      extensions/         # small Dart extension methods (BuildContext.theme shortcuts, etc.)
  test/
    unit/
    widget/
    integration/
```

Each `features/*` folder follows the same four-layer split (`presentation` / `application` / `data` /
`domain`) so the mock→Supabase swap later only touches `data/`, never `presentation/` — the same
principle the Next.js version used (`UI → hook → service → mock data`), just renamed to Flutter-idiomatic
terms.

## State management: Riverpod

**Decision:** Riverpod (`flutter_riverpod`, code-gen optional) as the one and only state-management
approach, used for both server-state (properties/tenants/payments/complaints, fetched from a repository)
and light UI state (dialog-open flags, selected property/PG, form state).

**Why, over the alternatives:**
- **vs. Provider** — Riverpod is Provider's successor from the same author, fixes Provider's
  context-dependency and compile-time-safety gaps, and is what the Flutter team and most current
  production apps have migrated to.
- **vs. Bloc** — Bloc's event/state ceremony is more boilerplate than this app's screens need (most
  screens are "fetch a list, mutate an item, refetch" — not complex event-sourced state machines).
  Riverpod's `AsyncNotifier`/`FutureProvider` covers that shape with far less code, and is easier for
  a small team to stay consistent in.
- **vs. GetX** — GetX trades structure for convenience (service locator magic, less testable) — wrong
  trade for a product that's explicitly meant to scale past MVP with real financial data.
- Riverpod providers are trivially mockable in `test/`, satisfying the testing-foundation requirement
  without extra wiring.

**How it's used:**
- One `Repository` per feature (`PropertiesRepository`, `PaymentsRepository`, ...) — an abstract
  interface with a `Mock*Repository` implementation now, a `Supabase*Repository` implementation later,
  selected by a single Riverpod override at the app root (exactly where the mock→Supabase swap happens).
- `AsyncNotifierProvider` per list/detail screen for loading/error/data states — maps directly to the
  Loading/Empty/Error/Success states §20 requires, with no separate ad-hoc state juggling per screen.
- A small number of plain `StateProvider`s for ephemeral UI state (current PG/property selection,
  dialog visibility) — replacing the Next.js prototype's `?pg=` query-param hack with a real,
  testable, in-memory selection that route params can still deep-link into via `go_router`.

## Routing

`go_router`, with one branch per role (`/owner/...`, `/manager/...`, `/tenant/...`) behind a redirect
that checks the resolved Profile's role — the same responsibility `requireRole()` had in the Next.js
app, just as a `go_router` redirect callback instead of a server-side guard (there is no server in this
architecture; the equivalent real security boundary is still Postgres RLS, once the database exists —
this redirect is routing UX only, exactly as the old `requireRole()` comment said).

## Offline assessment (§31 — explicit, not silent)

Reviewed each designed workflow for whether it needs offline support in this build:

| Workflow | Needs offline now? | Why |
|---|---|---|
| Viewing tenants/rooms/payments (read) | No | Cache via Riverpod's default provider retention is enough; a spinner on patchy wifi is acceptable for MVP |
| Recording a cash payment | **Not MVP, but the most likely first candidate later** | DECISIONS.md already lists an "offline-queue indicator" as a backlog idea for exactly this workflow — treat this build as confirming that backlog placement, not silently building offline queueing now |
| Updating a complaint (delegate/resolve) | No | Low-frequency, Manager-initiated, acceptable to require connectivity |
| Tenant confirming/disputing a cash payment | No | Same reasoning |

**Conclusion:** No offline architecture in this phase. Revisit cash-payment recording specifically once
real Managers report connectivity as an actual blocker, not preemptively.

## Notifications assessment (§32 — explicit, not silent)

Workflows that would want a notification once a backend exists: payment recorded (Tenant),
cash-confirmation requested (Tenant), payment disputed (Owner), rent due reminder (Tenant), complaint
delegated/resolved (Tenant), announcement posted (Tenant). **No push infrastructure in this phase** —
first build the UI/state architecture against mock data (an in-app "banner" like the design's
announcement card is enough to validate the UX); wire real push (FCM/APNs via Supabase or a BSP for
WhatsApp) once the backend phase adds a real event to notify about.

## Testing foundation (§34)

`test/unit` for repository/business-logic (e.g. the complaint `effectiveStatus()` auto-resolve
calculation — pure function, easy to unit test, and worth testing given the design's own README flags
it as the trickiest bit of logic in the app), `test/widget` for screen-level rendering of each state
(loading/empty/error/populated), `test/integration` reserved for the critical flows once they're built:
login → role routing, record payment → confirm/dispute, create complaint → delegate → auto-resolve,
move-out.
