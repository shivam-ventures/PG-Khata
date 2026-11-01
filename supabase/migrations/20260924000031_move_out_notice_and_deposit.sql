-- PG Khata — migration 31: a real move-out notice + deposit settlement flow.
--
-- `notice_period` has been a real `tenancies.status` value (and a real,
-- displayed status chip in the Flutter app) since migration 4 — but
-- nothing has ever been able to PUT a tenancy into that state. The only
-- existing action, move_out_tenant, always jumps straight from whatever
-- status a tenancy is in to 'moved_out', immediately. This migration adds
-- the missing middle: give notice (active -> notice_period, with a target
-- date), cancel it (back to active), and finalize it (-> moved_out, either
-- automatically once the date arrives via pg_cron, or early if staff/the
-- tenant forces it) — plus a deposit_settlement column so a move-out
-- always leaves an explicit, staff-visible answer for "does this person
-- get their deposit back", not silence.
--
-- Product decision (2026-09-24, explicitly flagged as likely to change):
-- notice must be at least 15 days, or the deposit is forfeited. This is
-- enforced as a soft gate, not a hard block — request_move_out refuses a
-- short-notice request unless the caller explicitly acknowledges the
-- forfeiture (p_acknowledge_forfeiture), so a real "I need to leave sooner
-- anyway" case still has a path through the app instead of requiring staff
-- to work around it outside the system. The old move_out_tenant (immediate,
-- no notice at all) is kept as-is for a genuine emergency/informal case —
-- it now also settles the deposit, treating zero notice the same way.

alter table tenancies
  add column deposit_settlement text
    check (deposit_settlement in ('pending', 'forfeited', 'returned')),
  add column notice_given_at date;

comment on column tenancies.deposit_settlement is
  'Null until a move-out is requested or finalized, or when no deposit was ever collected. "pending" means staff still needs to actually hand the deposit back outside the app and mark it returned — this table never moves real money.';

-- The one place "how many days' notice is enough" is decided — change
-- this single function if the 15-day policy or the forfeiture rule
-- changes, per this migration's own note that it's expected to.
create or replace function evaluate_move_out_notice(
  p_move_out_date date,
  p_has_deposit boolean
)
returns text
language sql
immutable
as $$
  select case
    when not p_has_deposit then null
    when p_move_out_date - current_date >= 15 then 'pending'
    else 'forfeited'
  end;
$$;

create or replace function request_move_out(
  p_tenancy_id uuid,
  p_move_out_date date,
  p_acknowledge_forfeiture boolean default false
)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenancy tenancies;
  v_property_id uuid;
  v_notice_days int;
begin
  select * into v_tenancy from tenancies where id = p_tenancy_id;
  if not found then
    raise exception 'tenancy % not found', p_tenancy_id;
  end if;

  select r.property_id into v_property_id
  from beds b join rooms r on r.id = b.room_id
  where b.id = v_tenancy.bed_id;

  if not (is_staff_for_property(v_property_id) or v_tenancy.profile_id = auth.uid()) then
    raise exception 'not authorized to give notice on this tenancy';
  end if;
  if v_tenancy.status <> 'active' then
    raise exception 'tenancy is not active (current status: %)', v_tenancy.status;
  end if;
  if p_move_out_date < current_date then
    raise exception 'move-out date cannot be in the past';
  end if;

  v_notice_days := p_move_out_date - current_date;
  if v_notice_days < 15 and not p_acknowledge_forfeiture then
    raise exception 'short_notice: only % days'' notice given — 15 required, or acknowledge deposit forfeiture to proceed', v_notice_days;
  end if;

  update tenancies
  set status = 'notice_period',
      move_out_date = p_move_out_date,
      notice_given_at = current_date,
      deposit_settlement = evaluate_move_out_notice(
        p_move_out_date, security_deposit_amount is not null
      )
  where id = p_tenancy_id
  returning * into v_tenancy;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_tenancy.org_id, 'tenancy.notice_given', 'tenancy', v_tenancy.id,
          jsonb_build_object(
            'move_out_date', p_move_out_date, 'notice_days', v_notice_days,
            'deposit_settlement', v_tenancy.deposit_settlement
          ));

  if auth.uid() = v_tenancy.profile_id then
    perform notify_staff_for_property(
      v_property_id, 'move_out_notice', 'Tenant gave notice',
      format('Planning to move out on %s (%s days'' notice).', p_move_out_date, v_notice_days),
      'tenancy', v_tenancy.id
    );
  else
    perform notify_user(
      v_tenancy.profile_id, 'move_out_notice', 'Move-out notice recorded',
      format('Your move-out is scheduled for %s.%s', p_move_out_date,
             case when v_tenancy.deposit_settlement = 'forfeited'
                  then ' Since this is less than 15 days'' notice, your security deposit will not be refunded.'
                  else '' end),
      'tenancy', v_tenancy.id
    );
  end if;

  return v_tenancy;
end;
$$;

create or replace function cancel_move_out_notice(p_tenancy_id uuid)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenancy tenancies;
  v_property_id uuid;
begin
  select * into v_tenancy from tenancies where id = p_tenancy_id;
  if not found then
    raise exception 'tenancy % not found', p_tenancy_id;
  end if;

  select r.property_id into v_property_id
  from beds b join rooms r on r.id = b.room_id
  where b.id = v_tenancy.bed_id;

  if not (is_staff_for_property(v_property_id) or v_tenancy.profile_id = auth.uid()) then
    raise exception 'not authorized to cancel notice on this tenancy';
  end if;
  if v_tenancy.status <> 'notice_period' then
    raise exception 'tenancy is not in its notice period (current status: %)', v_tenancy.status;
  end if;

  update tenancies
  set status = 'active', move_out_date = null, notice_given_at = null, deposit_settlement = null
  where id = p_tenancy_id
  returning * into v_tenancy;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_tenancy.org_id, 'tenancy.notice_cancelled', 'tenancy', v_tenancy.id, '{}');

  if auth.uid() = v_tenancy.profile_id then
    perform notify_staff_for_property(
      v_property_id, 'move_out_notice_cancelled', 'Tenant cancelled their move-out notice',
      'They''re staying — no bed change needed.', 'tenancy', v_tenancy.id
    );
  else
    perform notify_user(
      v_tenancy.profile_id, 'move_out_notice_cancelled', 'Your move-out notice was cancelled',
      'You''re still an active tenant here.', 'tenancy', v_tenancy.id
    );
  end if;

  return v_tenancy;
end;
$$;

-- The pre-existing immediate move-out — unchanged authorization/shape,
-- now also settles the deposit rather than leaving it null. Called
-- directly from 'active' it's a zero-notice move-out (deposit forfeited
-- if one was collected, same rule as any other short notice); called from
-- 'notice_period' it finalizes early and keeps whatever
-- request_move_out already decided.
create or replace function move_out_tenant(p_tenancy_id uuid)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenancy tenancies;
  v_property_id uuid;
begin
  select * into v_tenancy from tenancies where id = p_tenancy_id;
  if not found then
    raise exception 'tenancy % not found', p_tenancy_id;
  end if;

  select r.property_id into v_property_id
  from beds b join rooms r on r.id = b.room_id
  where b.id = v_tenancy.bed_id;

  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to move out this tenant';
  end if;
  if v_tenancy.status = 'moved_out' then
    raise exception 'tenancy is already moved out';
  end if;

  update tenancies
  set status = 'moved_out',
      move_out_date = current_date,
      deposit_settlement = coalesce(
        deposit_settlement,
        evaluate_move_out_notice(current_date, security_deposit_amount is not null)
      )
  where id = p_tenancy_id
  returning * into v_tenancy;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_tenancy.org_id, 'tenancy.moved_out', 'tenancy', v_tenancy.id,
          jsonb_build_object('deposit_settlement', v_tenancy.deposit_settlement));

  return v_tenancy;
end;
$$;

comment on function move_out_tenant(uuid) is
  'Closes the tenancy (status -> moved_out) which is ALSO how the bed becomes vacant again — bed_occupancy is derived, so this single update is the whole operation. Also settles the deposit if request_move_out hasn''t already (see evaluate_move_out_notice) — a direct call from ''active'' is a zero-notice move-out by definition.';

-- Staff-only: record that a pending deposit was actually handed back
-- outside the app (this table never moves real money itself).
create or replace function mark_deposit_returned(p_tenancy_id uuid)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenancy tenancies;
  v_property_id uuid;
begin
  select * into v_tenancy from tenancies where id = p_tenancy_id;
  if not found then
    raise exception 'tenancy % not found', p_tenancy_id;
  end if;

  select r.property_id into v_property_id
  from beds b join rooms r on r.id = b.room_id
  where b.id = v_tenancy.bed_id;

  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to settle this tenancy''s deposit';
  end if;
  if v_tenancy.deposit_settlement is null then
    raise exception 'this tenancy has no deposit to settle';
  end if;

  update tenancies set deposit_settlement = 'returned'
  where id = p_tenancy_id
  returning * into v_tenancy;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_tenancy.org_id, 'tenancy.deposit_returned', 'tenancy', v_tenancy.id, '{}');

  return v_tenancy;
end;
$$;

-- Scheduled (pg_cron), same pattern and same auth.uid()-is-null guard as
-- generate_rent_periods — auto-finalizes any notice_period tenancy whose
-- planned move-out date has arrived, so staff doesn't have to remember to
-- click anything for the ordinary case. Finalizing early by choice still
-- goes through move_out_tenant directly.
create or replace function finalize_due_move_outs()
returns setof tenancies
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    raise exception 'finalize_due_move_outs is scheduled/service-role only';
  end if;

  return query
  update tenancies
  set status = 'moved_out'
  where status = 'notice_period' and move_out_date <= current_date
  returning *;
end;
$$;

comment on function finalize_due_move_outs() is
  'Run daily by pg_cron — moves every notice_period tenancy whose move_out_date has arrived to moved_out. deposit_settlement was already decided by request_move_out, so this never touches it.';

select
  cron.schedule(
    'finalize-move-outs-daily',
    '10 0 * * *',
    $$select finalize_due_move_outs()$$
  )
where not exists (
  select 1 from cron.job where jobname = 'finalize-move-outs-daily'
);
