-- PG Khata — migration 39: fix a regression migration 33 introduced.
--
-- Found immediately while testing migration 33-38 end to end against the
-- real app (2026-09-25): migration 33 made `paid_amount` always the
-- CONFIRMED-paid total (via rent_period_paid_total, which only sums
-- status = 'paid' allocations) — correct for computing status and for
-- property_metrics' rent_collected, but it silently dropped what the
-- column used to also carry: the LATEST payment attempt's claimed amount,
-- regardless of that attempt's own status. That mattered for two real UI
-- cases migration 33 didn't account for:
--   1. A pending/overdue period with NO payment at all now gets
--      paid_amount = 0 (coalesce's default) instead of NULL — the
--      Flutter client's `paidAmount ?? amountDue` fallback only fires on
--      NULL, so `amount` silently became 0 instead of falling back to
--      amount_due. This is what broke the Owner Payments screen's
--      Pending/Collection-rate stats immediately upon testing.
--   2. An awaiting_confirmation or disputed period's "claimed" amount
--      (e.g. "Manager recorded ₹500, awaiting your confirmation") is a
--      DIFFERENT number from the confirmed-paid total, and the UI needs
--      both, not just one.
--
-- Fix: add a new trailing column, latest_amount (the latest non-voided
-- attempt's own amount, whatever its status — this is what the column
-- used to always mean), alongside the now-correct paid_amount (confirmed
-- total only). Added at the end, not reordering/renaming anything, so
-- this is a safe `create or replace view` (see migration 33's own note on
-- why that matters).

create or replace view rent_period_status as
select
  rp.id as rent_period_id,
  rp.tenancy_id,
  rp.period_month,
  rp.due_date,
  rp.amount_due,
  rp.org_id,
  case
    when exists (
      select 1 from payments p where p.rent_period_id = rp.id and p.status = 'disputed'
    ) then 'disputed'
    when exists (
      select 1 from payments p where p.rent_period_id = rp.id and p.status = 'awaiting_confirmation'
    ) then 'awaiting_confirmation'
    when rent_period_paid_total(rp.id) >= rp.amount_due then 'paid'
    when rent_period_paid_total(rp.id) > 0 then 'partial'
    when rp.due_date < current_date then 'overdue'
    else 'pending'
  end as status,
  latest.id as latest_payment_id,
  rent_period_paid_total(rp.id)::numeric(10, 2) as paid_amount,
  latest.method,
  latest.is_self_recorded,
  latest.paid_at,
  -- New in migration 39 — see this migration's comment. NULL, same as
  -- before migration 33, when there has never been a payment attempt at
  -- all (pending/overdue with nothing recorded yet).
  latest.amount as latest_amount
from rent_periods rp
left join lateral (
  select *
  from payments p
  where p.rent_period_id = rp.id and p.status <> 'voided'
  order by p.created_at desc
  limit 1
) latest on true;

alter view rent_period_status set (security_invoker = true);
revoke select on rent_period_status from anon;

comment on view rent_period_status is
  'The read model the Owner/Manager/Tenant payment screens use — one row per period. paid_amount is the confirmed (status=paid) total across every allocation (migration 33/39) — use it for "how much has actually settled". latest_amount is the latest attempt''s own claimed amount regardless of its status (NULL if none) — use it for "what does the most recent claim say", e.g. an awaiting_confirmation/disputed display. security_invoker = true MUST stay set (migration 19).';
