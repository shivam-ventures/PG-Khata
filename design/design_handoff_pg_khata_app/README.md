# Handoff: PG Khata — PG Management App (Owner / Manager / Tenant)

## Overview
A mobile-first app for managing paying-guest (PG) accommodations, with three roles: **Owner** (portfolio-level oversight), **Manager** (day-to-day operations at one or more PGs), and **Tenant** (self-service for the resident). Covers auth/onboarding, rent payments (incl. cash confirmation loop), room/bed occupancy, complaints (with a delegate-and-auto-resolve model), tenant management, and reports.

## About the Design Files
The files in `screens/` are **design references built in HTML** — interactive prototypes showing intended layout, content, and behavior. They are not production code to copy directly. The task is to **recreate these designs in the target codebase's environment** (React Native, Flutter, native iOS/Android, or web — whichever the project uses) using that codebase's existing component patterns, navigation, and state management. If no environment exists yet, choose the framework best suited to a mobile-first app and implement the designs there.

Each screen file is self-contained HTML/CSS/JS (custom lightweight component format) — open any file directly in a browser to see it render and interact with it. Mock data lives inline in each file's script block.

## Fidelity
**High-fidelity.** Colors, type, spacing, and copy are final per the attached design system ("Modernist"). Recreate pixel-close using the design tokens below, substituting the codebase's own component library where equivalent components already exist (e.g. native buttons/inputs) rather than reinventing them.

## App structure
All screens share a **480px-wide mobile shell** (`max-width:480px; margin:0 auto`), a sticky header (back arrow + title + role switcher + theme toggle), a bottom nav bar (`.bottom-nav-v2`, 4 tabs), and use dialogs/modals (`.dialog-backdrop` + `.dialog`) for forms instead of separate pages. No desktop/table-style layouts anywhere — everything is card lists.

### Roles & navigation
- **Owner**: `Owner Dashboard` → tabs/links to `Properties`, `Owner Rooms`, `Owner Tenants`, `Owner Payments`, `Reports`, `Tenant Complaints (legacy)`/Complaints view, `Settings`. Has a property/PG portfolio switcher (`PortfolioSwitcher.dc.html`) in the header area for multi-property owners.
- **Manager**: `Manager Today` (home) → bottom nav: Today, `Manager Payments`, `Manager Rooms`, `Manager More` (→ `Manager Tenants`, `Manager Complaints`, Settings). Also has the PG switcher bar if managing multiple properties.
- **Tenant**: `Tenant Home` (home) → bottom nav: Home, `Tenant Payments`, `Tenant Complaints`, Profile (`Settings.dc.html?role=tenant`). No portfolio switcher — tenant belongs to one PG/bed.
- `RoleSwitcher.dc.html` is a small header widget to preview/switch role context (dev/demo aid — decide with your team whether it ships to production or is prototype-only).
- `Auth.dc.html` covers login + self-registration (tenant signs up, manager later assigns them to a bed) and an invite-link path (bed-specific QR/link for faster tenant setup).

## Key flows / behavior

### Payments
- Rent payments support **cash and digital**. Cash payments use a **confirm loop**: manager records a cash payment received → tenant sees it and confirms or disputes it (rather than the manager's word being final). See `Manager Payments.dc.html` and `Tenant Payments.dc.html`.
- Owner-level `Owner Payments.dc.html` rolls up payment status across properties/tenants for oversight, reachable from `Owner Dashboard`.

### Complaints (recently redesigned — this is the most important flow to get right)
Old model (now replaced): tenant reports → manager sets status via dropdown (Reported/In Progress/Resolved) → tenant confirms fixed. Too many required steps for a manager who typically just verbally delegates and never personally verifies.

**New model**, implemented in `Manager Complaints.dc.html` and `Tenant Complaints.dc.html`:
- Complaint statuses: `Reported` → `Delegated` → `Resolved` (or `Reopened`).
- Manager's only required action is **"Delegate & done"**: pick who's handling it (Self / Cleaner / Electrician / Plumber / Outside vendor) + optional note, one tap. No status dropdown, no forced follow-up.
- Once delegated, the ticket **auto-resolves after 3 days** if the tenant doesn't say otherwise — this is computed client-side from `delegatedAt + autoResolveDays` vs. now (see `effectiveStatus()` in both files' script blocks). In production this should be a scheduled/derived server-side status, not a client-only computation.
- Manager can optionally "Reassign" or "Mark resolved now" early, but neither is required.
- Tenant sees "Being handled by {assignee} · auto-closes in Nd" and a lightweight "Not fixed yet?" link that reopens the ticket (sets status back to `Reported`/`Reopened`) — there's no required "confirm fixed" tap, since tenants generally won't bother closing tickets themselves.
- High-priority complaints show a small red dot on the category icon; stat cards at the top of Manager Complaints count "Open" and "High priority" using the *effective* (auto-resolved-aware) status, not the raw stored status.

### Move-out
Owner/Manager can mark a tenant as vacated: frees the bed, stops rent accrual for that tenant. (Referenced from `Owner Rooms.dc.html` / `Owner Tenants.dc.html` — check those files for the exact dialog copy and fields.)

### Reports
`Reports.dc.html` — Owner-facing rollups (occupancy, collections, etc.), reachable from Owner Dashboard.

## Design Tokens
Full token source is the linked stylesheet: `screens/_ds/modernist-*/styles.css` (design system name: "Modernist"). Do not hand-copy hex values from screenshots — read them from that CSS file's `:root` variables. Summary of the system's intent:
- **Color**: light ground `--color-bg` (#f3f2f2), ink `--color-text` (#201e1d), single accent `--color-accent` (#ec3013, red). Each role (neutral/accent/accent-2) has a 100–900 OKLCH tonal ramp — light steps (100–300) for tints/hovers, 500 as base, 700–900 for text-on-tint and pressed states.
- **Type**: Archivo for both headings and body (`--font-heading` / `--font-body`).
- **Radius**: `--radius-md` is **0** — this system is intentionally square-cornered everywhere. Do not round corners.
- **Shadows**: `--shadow-sm/md/lg` for elevation instead of ad-hoc box-shadows.
- **Spacing**: use `--space-*` scale, not raw px.
- This app also layers a small `tokens-extra.css` on top (check it for a couple of extra semantic classes like `.tag-neutral`, `.bottom-nav-v2`, `.stat-card`, `.task-card`, `.list-card` used throughout the screens).
- Icons throughout are inline Lucide-style SVG paths (stroke-based, 18–20px). Recreate with your icon library's equivalent glyphs (search/settings/wallet/wrench/wifi/droplet etc. per screen) rather than re-drawing the raw paths.

## Assets
No photographic/image assets — the app is entirely typographic + inline SVG icons + card layouts. No icons files to extract; icon paths are inline `<path d="...">` inside each screen's markup, one per icon use.

## Files
```
screens/
  Auth.dc.html                    — login, self-registration, invite-link onboarding
  Owner Dashboard.dc.html         — owner home, "needs attention" summary, quick actions
  Properties.dc.html              — owner's PG portfolio list
  Owner Rooms.dc.html             — room/bed occupancy (owner view)
  Owner Tenants.dc.html           — tenant roster (owner view)
  Owner Payments.dc.html          — payments rollup (owner view)
  Reports.dc.html                 — owner reports/analytics
  PortfolioSwitcher.dc.html       — multi-property switcher widget
  Manager Today.dc.html           — manager home
  Manager Payments.dc.html        — record/confirm rent payments (manager)
  Manager Rooms.dc.html           — room/bed management (manager)
  Manager Tenants.dc.html         — tenant roster + move-out (manager)
  Manager Complaints.dc.html      — complaint delegate/auto-resolve flow (manager) — see above
  Manager More.dc.html            — manager overflow menu
  Tenant Home.dc.html             — tenant home
  Tenant Payments.dc.html         — tenant rent + cash-payment confirm/dispute
  Tenant Complaints.dc.html       — tenant report/track complaints — see above
  Tenant Complaints (legacy).dc.html — superseded generic complaints view; kept for reference only, not part of the current flow
  Settings.dc.html                — shared settings/profile, role-aware via ?role= query param
  RoleSwitcher.dc.html             — dev/demo role-switch widget
  tokens-extra.css                 — extra shared classes on top of the design system
  support.js                       — internal runtime for these prototype files (not needed in production port)
  _ds/                             — the "Modernist" design system bundle (styles.css + tokens) these screens are built on
```

## Open items / things to confirm with design before/while building
- The complaint auto-resolve timer (3 days) is currently a hardcoded constant computed client-side against `Date.now()` — needs a real backend job/derivation.
- `Complaints.dc.html` ("Tenant Complaints (legacy)") duplicates `Tenant Complaints.dc.html` — use the latter; the legacy file is included only so you can diff what changed.
- `RoleSwitcher.dc.html` is likely a prototyping aid only — confirm whether real users ever switch roles in one session or whether this is strictly per-account.
