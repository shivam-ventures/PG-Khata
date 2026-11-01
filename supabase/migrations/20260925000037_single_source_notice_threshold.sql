-- PG Khata — migration 37: make the 15-day move-out notice threshold a
-- real single source of truth on the backend.
--
-- Gap found during the pre-launch audit (2026-09-25): migration 31's own
-- comment claims "The one place 'how many days' notice is enough' is
-- decided — change this single function [evaluate_move_out_notice] if the
-- 15-day policy ... changes." That claim was not actually true:
-- request_move_out had its OWN separate `v_notice_days < 15` comparison
-- and its own hardcoded "15 required" text in the raised exception message
-- — a change to evaluate_move_out_notice's threshold would silently stop
-- matching what request_move_out actually enforces. This adds the real
-- single source (minimum_notice_days()) and makes both functions, plus
-- the error message text, derive from it.

create or replace function minimum_notice_days()
returns int
language sql
immutable
as $$
  select 15;
$$;

comment on function minimum_notice_days() is
  'The ONE place the move-out notice policy''s day threshold is decided. evaluate_move_out_notice and request_move_out both derive from this — change it here, not in either of those, if the policy changes (see migration 31''s original note, corrected by migration 37).';

create or replace function evaluate_move_out_notice(
  p_move_out_date date,
  p_has_deposit boolean
)
returns text
language sql
stable
as $$
  select case
    when not p_has_deposit then null
    when p_move_out_date - current_date >= minimum_notice_days() then 'pending'
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
  if v_notice_days < minimum_notice_days() and not p_acknowledge_forfeiture then
    raise exception 'short_notice: only % days'' notice given — % required, or acknowledge deposit forfeiture to proceed',
      v_notice_days, minimum_notice_days();
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
                  then ' Since this is less than ' || minimum_notice_days() || ' days'' notice, your security deposit will not be refunded.'
                  else '' end),
      'tenancy', v_tenancy.id
    );
  end if;

  return v_tenancy;
end;
$$;

grant execute on function minimum_notice_days() to authenticated;
