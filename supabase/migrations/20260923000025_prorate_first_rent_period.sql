-- PG Khata — migration 25: prorate a new tenancy's first rent period.
--
-- generate_rent_periods() (migration 9) only ever creates a period for the
-- CURRENT calendar month, on whatever schedule it's run. A tenant who
-- joins mid-month (after that month's run already happened) would get NO
-- rent_period at all until next month — effectively a free partial month.
-- Product decision (2026-09-23): prorate the first period by days
-- remaining in the move-in month, generated immediately at tenancy
-- creation rather than waiting for the scheduled run.
--
-- This lives inside create_tenancy_for_profile — the single low-level
-- function every tenancy-creation path already funnels through
-- (add-tenant, complete_invite_join, assign_tenant_to_bed,
-- transfer_tenancy) — so every path gets this for free, atomically, with
-- no per-caller duplication.
--
-- The prorated period's due_date is the move-in date itself (due on
-- joining) rather than that month's rent_due_day, since rent_due_day may
-- already have passed by the time someone joins mid-month. Every
-- subsequent month reverts to the normal rent_due_day cadence via
-- generate_rent_periods(), which no-ops for a tenancy's first month
-- because of the (tenancy_id, period_month) unique index.

create or replace function create_tenancy_for_profile(
  p_profile_id uuid,
  p_bed_id uuid,
  p_rent_amount numeric,
  p_rent_due_day smallint default 5,
  p_deposit_amount numeric default null,
  p_move_in_date date default current_date,
  p_source text default 'staff_created',
  p_created_by uuid default null
)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenancy tenancies;
  v_days_in_month int;
  v_days_remaining int;
  v_prorated_amount numeric;
begin
  insert into tenancies (
    profile_id, bed_id, status, source, move_in_date, rent_amount,
    rent_due_day, security_deposit_amount, created_by
  )
  values (
    p_profile_id, p_bed_id, 'active', p_source, p_move_in_date, p_rent_amount,
    p_rent_due_day, p_deposit_amount, p_created_by
  )
  returning * into v_tenancy;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (coalesce(p_created_by, p_profile_id), v_tenancy.org_id, 'tenancy.created', 'tenancy', v_tenancy.id,
          jsonb_build_object('source', p_source));

  v_days_in_month := extract(day from (date_trunc('month', p_move_in_date) + interval '1 month - 1 day'))::int;
  v_days_remaining := v_days_in_month - extract(day from p_move_in_date)::int + 1;
  v_prorated_amount := round(p_rent_amount * v_days_remaining / v_days_in_month, 2);

  insert into rent_periods (tenancy_id, period_month, due_date, amount_due)
  values (v_tenancy.id, date_trunc('month', p_move_in_date)::date, p_move_in_date, v_prorated_amount)
  on conflict (tenancy_id, period_month) do nothing;

  return v_tenancy;
end;
$$;

comment on function create_tenancy_for_profile(uuid, uuid, numeric, smallint, numeric, date, text, uuid) is
  'The single internal function every tenancy-creation path (add-tenant, complete_invite_join, assign_tenant_to_bed, transfer_tenancy) funnels through — also generates that tenancy''s first, prorated rent period immediately, so a mid-month join is never left unbilled until the next scheduled generate_rent_periods() run. See migration 25.';
