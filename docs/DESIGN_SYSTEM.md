# Design system — quick reference

Full rationale lives in the "MVP Build Plan, Design System & Engineering
Architecture" document from the planning phase. This file is the fast
lookup for anyone writing code.

## Where tokens live

All color tokens are CSS variables in `src/app/globals.css` (light values
under `:root`, dark values under `.dark`), wired into Tailwind via
`tailwind.config.ts`. Never hardcode a hex color in a component — use the
Tailwind class (`bg-primary`, `text-danger`, `border-border`, etc.) so
light/dark and any future re-theme stay centralized.

## Rules every screen follows

- One primary action per screen. If a screen wants two, one of them is
  probably secondary — use `variant="ghost"` or `variant="outline"`.
- Every loading state is a `<Skeleton>` shaped like the real content, never
  a bare spinner on a data-heavy screen.
- Every empty state uses `<EmptyState>` — a short encouraging line plus the
  one action that fills it.
- Status is always shown via `<PaymentStatusChip>` / `<ComplaintStatusChip>`
  / `<VerificationStatusChip>` (`src/components/status-chip.tsx`) — never a
  hand-picked badge color, so "Overdue" is red everywhere or nowhere.
- Radius: `rounded-sm` (8px) inputs/chips, default `rounded-md` (12px)
  buttons, `rounded-lg` (16px) cards, `rounded-xl` (24px) sheets/modals.
- Shadows are soft only (`shadow-sm` / `shadow-md` / `shadow-lg` as defined
  in `tailwind.config.ts`) — never a hard drop-shadow.

## Component inventory status

Built in Phase 0 (`src/components/ui/`): Button, Card, Input, Label,
Avatar, Badge, Skeleton, Separator, Tabs, Dialog, Sheet, Dropdown Menu,
Sonner (toast).

Domain components (`src/components/`): StatCard, EmptyState, StatusChip
family, ThemeToggle, RoleShell + NavSidebar/NavBottom.

Not yet built — added when the feature that needs them is built, not
before: Timeline, Activity feed, Charts, Calendar/date-range picker,
Search, Filters, Room/Tenant/Complaint cards (these are compositions of
Card + StatusChip + Avatar, built in Phase 1/2/5).
