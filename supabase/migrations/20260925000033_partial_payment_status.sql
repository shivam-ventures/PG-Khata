-- PG Khata — migration 33: fix rent_period_status to reflect the TOTAL
-- confirmed-paid amount for a period, not just its single latest payment
-- attempt, and introduce a real 'partial' status.
--
-- Bug found during the pre-launch audit (2026-09-25): the previous
-- rent_period_status derived both `status` and `paid_amount` from a lateral
-- join picking only the single most recent non-voided payment row. Since
-- payment_allocations/payments has always supported more than one payment
-- attempt against one rent_period (partial payment, then a top-up — see
-- migration 5's own comments), this meant:
--   - a period paid off via two partial payments showed only the second
--     payment's amount, silently losing the first;
--   - once a partial payment was staff-recorded and tenant-confirmed, the
--     period read as fully 'paid' even though amount_due hadn't been met —
--     there was no 'partial' status at all;
--   - a later, smaller disputed/awaiting attempt against an
--     already-fully-paid period could flip the period's displayed status
--     backward, because "latest wins" applied to status too.
--
-- Fix: paid_amount is now a true sum of every non-voided, CONFIRMED
-- ('paid') payment's allocations against the period. status priority is:
-- an active dispute or an unconfirmed staff claim always surfaces first
-- (something needs action), then paid/partial is derived by comparing the
-- confirmed total against amount_due, then pending/overdue as before.

create or replace function rent_period_paid_total(target_rent_period_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(pa.amount_allocated), 0)
  from payment_allocations pa
  join payments p on p.id = pa.payment_id
  where pa.rent_period_id = target_rent_period_id and p.status = 'paid';
$$;

comment on function rent_period_paid_total(uuid) is
  'Sum of every CONFIRMED (status = paid) payment allocation against a rent period — the real "money actually received and confirmed" total, as opposed to any single payment attempt. Used by rent_period_status and rent_period_remaining_balance.';

create or replace function rent_period_remaining_balance(target_rent_period_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select rp.amount_due - rent_period_paid_total(rp.id)
  from rent_periods rp
  where rp.id = target_rent_period_id;
$$;

comment on function rent_period_remaining_balance(uuid) is
  'amount_due minus the confirmed-paid total — what is actually still owed on this period. Negative if overpaid. Used by record_self_payment (migration 34) to validate a tenant''s own payment matches what they actually owe.';

create or replace view rent_period_status as
select
  rp.id as rent_period_id,
  rp.tenancy_id,
  rp.period_month,
  rp.due_date,
  rp.amount_due,
  rp.org_id,
  -- Column order/names from here down MUST stay exactly as they were
  -- before this migration (status, then latest_payment_id, then
  -- paid_amount, ...) — `create or replace view` can add columns at the
  -- end but cannot rename or reorder existing ones (Postgres error 42P16,
  -- hit and fixed while pushing this migration the first time). Only the
  -- COMPUTATION of status/paid_amount changes here, not their position.
  case
    -- An active dispute or an unconfirmed staff claim always needs someone
    -- to act on it, regardless of how much of the period is otherwise
    -- covered — surfacing these first is intentional, not a leftover of
    -- the old "latest wins" bug (see comment in confirm/dispute below for
    -- why this is still the right call, not an accidental regression).
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
  -- Cast to match the original column's numeric(10,2) type exactly —
  -- rent_period_paid_total() returns plain numeric, and `create or
  -- replace view` also rejects a data-type change on an existing column,
  -- not just a reorder/rename (Postgres error 42P16 again).
  rent_period_paid_total(rp.id)::numeric(10, 2) as paid_amount,
  latest.method,
  latest.is_self_recorded,
  latest.paid_at
from rent_periods rp
left join lateral (
  select *
  from payments p
  where p.rent_period_id = rp.id and p.status <> 'voided'
  order by p.created_at desc
  limit 1
) latest on true;

-- Preserve the RLS-safety fix from migration 19 — a view defaults to
-- security_invoker = false (the view owner's privileges, bypassing RLS on
-- the underlying tables) unless told otherwise. This was a real
-- cross-organization data leak once already; do not let it regress here.
alter view rent_period_status set (security_invoker = true);
revoke select on rent_period_status from anon;

comment on view rent_period_status is
  'The read model the Owner/Manager/Tenant payment screens use — one row per period. paid_amount is the TRUE sum of confirmed payments against this period (fixed in migration 33 — was previously only the latest attempt''s amount). security_invoker = true MUST stay set (migration 19).';

-- property_metrics' rent_collected must count a partial period''s confirmed
-- portion too, not just fully-'paid' periods, or portfolio rollups
-- undercount real money received the same way the old per-period view did.
create or replace view property_metrics as
with beds_agg as (
  select
    r.property_id,
    count(b.id) as total_beds,
    count(b.id) filter (where bo.is_occupied) as occupied_beds
  from rooms r
  join beds b on b.room_id = r.id
  left join bed_occupancy bo on bo.bed_id = b.id
  where r.archived_at is null and b.archived_at is null
  group by r.property_id
),
latest_period as (
  select distinct on (t.id)
    t.id as tenancy_id,
    rp.id as rent_period_id,
    r.property_id
  from tenancies t
  join rent_periods rp on rp.tenancy_id = t.id
  join beds b on b.id = t.bed_id
  join rooms r on r.id = b.room_id
  where t.status in ('active', 'notice_period')
  order by t.id, rp.period_month desc
),
payments_agg as (
  select
    lp.property_id,
    sum(rps.amount_due) as rent_expected,
    sum(rps.paid_amount) filter (where rps.status in ('paid', 'partial')) as rent_collected
  from latest_period lp
  join rent_period_status rps on rps.rent_period_id = lp.rent_period_id
  group by lp.property_id
),
complaints_agg as (
  select property_id, count(*) as open_complaints
  from complaints c
  where complaint_effective_status(c) <> 'resolved'
  group by property_id
)
select
  p.id as property_id,
  p.org_id,
  coalesce(ba.total_beds, 0) as total_beds,
  coalesce(ba.occupied_beds, 0) as occupied_beds,
  coalesce(pa.rent_collected, 0) as rent_collected,
  coalesce(pa.rent_expected, 0) as rent_expected,
  coalesce(ca.open_complaints, 0) as open_complaints
from properties p
left join beds_agg ba on ba.property_id = p.id
left join payments_agg pa on pa.property_id = p.id
left join complaints_agg ca on ca.property_id = p.id
where p.archived_at is null;

alter view property_metrics set (security_invoker = true);
revoke select on property_metrics from anon;

grant execute on function rent_period_paid_total(uuid) to authenticated;
grant execute on function rent_period_remaining_balance(uuid) to authenticated;

comment on function rent_period_paid_total(uuid) is
  'Referenced inside rent_period_status/property_metrics (views run with the querying role under security_invoker = true) and inside record_self_payment''s validation (migration 34) — must stay granted to authenticated, same reasoning as is_owner_of_org (migration 18).';
