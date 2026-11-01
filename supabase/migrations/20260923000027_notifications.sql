-- PG Khata — migration 27: wire up in-app notifications.
--
-- migration 7 created the `notifications` table and migration 12 gave it
-- RLS ("read own" / "mark own read"), but nothing has ever written a row
-- into it — the table has sat empty since Phase 1. This migration adds
-- two small helpers and threads notify_* calls through the existing
-- payment/complaint/tenancy RPCs at the same points they already write to
-- audit_log, so the two logs stay in sync without duplicating the
-- authorization/validation logic those RPCs already have.

create or replace function notify_user(
  p_recipient uuid,
  p_kind text,
  p_title text,
  p_body text default null,
  p_entity_type text default null,
  p_entity_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient is null then
    return;
  end if;
  insert into notifications (recipient_user_id, kind, title, body, entity_type, entity_id)
  values (p_recipient, p_kind, p_title, p_body, p_entity_type, p_entity_id);
end;
$$;

-- The org's Owner plus every Manager currently assigned to the property —
-- the same "who counts as staff here" set is_staff_for_property() checks.
create or replace function notify_staff_for_property(
  p_property_id uuid,
  p_kind text,
  p_title text,
  p_body text default null,
  p_entity_type text default null,
  p_entity_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_manager_id uuid;
begin
  perform notify_user(
    (select o.owner_user_id from organizations o join properties p on p.org_id = o.id where p.id = p_property_id),
    p_kind, p_title, p_body, p_entity_type, p_entity_id
  );
  for v_manager_id in
    select manager_user_id from property_managers
    where property_id = p_property_id and unassigned_at is null
  loop
    perform notify_user(v_manager_id, p_kind, p_title, p_body, p_entity_type, p_entity_id);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------

create or replace function record_payment(
  p_rent_period_id uuid,
  p_method text,
  p_amount numeric,
  p_idempotency_key text default null
)
returns payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_payment payments;
  v_tenant_id uuid;
begin
  v_property_id := property_id_for_rent_period(p_rent_period_id);
  if v_property_id is null then
    raise exception 'rent period % not found', p_rent_period_id;
  end if;
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to record a payment for this property';
  end if;

  if p_idempotency_key is not null then
    select * into v_payment from payments where idempotency_key = p_idempotency_key;
    if found then
      return v_payment;
    end if;
  end if;

  insert into payments (rent_period_id, amount, method, recorded_by, is_self_recorded, status, idempotency_key)
  values (p_rent_period_id, p_amount, p_method, auth.uid(), false, 'awaiting_confirmation', p_idempotency_key)
  returning * into v_payment;

  insert into payment_allocations (payment_id, rent_period_id, amount_allocated)
  values (v_payment.id, p_rent_period_id, p_amount);

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_payment.org_id, 'payment.recorded', 'payment', v_payment.id,
          jsonb_build_object('method', p_method, 'amount', p_amount));

  select t.profile_id into v_tenant_id
  from rent_periods rp join tenancies t on t.id = rp.tenancy_id
  where rp.id = p_rent_period_id;
  perform notify_user(
    v_tenant_id, 'payment_recorded', 'Payment recorded',
    format('A %s payment of ₹%s was recorded for your rent. Please confirm it went through.', p_method, p_amount),
    'payment', v_payment.id
  );

  return v_payment;
end;
$$;

create or replace function confirm_payment(p_payment_id uuid)
returns payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment payments;
begin
  if not tenant_owns_payment(p_payment_id) then
    raise exception 'not authorized to confirm this payment';
  end if;

  select * into v_payment from payments where id = p_payment_id;
  if not found then
    raise exception 'payment % not found', p_payment_id;
  end if;
  if v_payment.status <> 'awaiting_confirmation' then
    raise exception 'payment is not awaiting confirmation (current status: %)', v_payment.status;
  end if;

  update payments set status = 'paid' where id = p_payment_id returning * into v_payment;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_payment.org_id, 'payment.confirmed', 'payment', v_payment.id, '{}');

  if v_payment.recorded_by is not null and not v_payment.is_self_recorded then
    perform notify_user(
      v_payment.recorded_by, 'payment_confirmed', 'Payment confirmed',
      'The tenant confirmed the payment you recorded.', 'payment', v_payment.id
    );
  end if;

  return v_payment;
end;
$$;

create or replace function dispute_payment(p_payment_id uuid)
returns payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment payments;
  v_property_id uuid;
begin
  if not tenant_owns_payment(p_payment_id) then
    raise exception 'not authorized to dispute this payment';
  end if;

  select * into v_payment from payments where id = p_payment_id;
  if not found then
    raise exception 'payment % not found', p_payment_id;
  end if;
  if v_payment.status <> 'awaiting_confirmation' then
    raise exception 'payment is not awaiting confirmation (current status: %)', v_payment.status;
  end if;

  update payments set status = 'disputed' where id = p_payment_id returning * into v_payment;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_payment.org_id, 'payment.disputed', 'payment', v_payment.id, '{}');

  v_property_id := property_id_for_payment(p_payment_id);
  perform notify_staff_for_property(
    v_property_id, 'payment_disputed', 'Payment disputed',
    'A tenant disputed a payment claim that''s awaiting confirmation — Owner review needed.',
    'payment', v_payment.id
  );

  return v_payment;
end;
$$;

create or replace function void_payment(p_payment_id uuid)
returns payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment payments;
  v_property_id uuid;
  v_tenant_id uuid;
begin
  select * into v_payment from payments where id = p_payment_id;
  if not found then
    raise exception 'payment % not found', p_payment_id;
  end if;

  v_property_id := property_id_for_payment(p_payment_id);
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to void this payment';
  end if;

  if v_payment.status = 'disputed' then
    raise exception 'a disputed payment must be resolved via resolve_dispute, not void_payment';
  end if;
  if v_payment.status = 'voided' then
    raise exception 'payment is already voided';
  end if;

  update payments set status = 'voided' where id = p_payment_id returning * into v_payment;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_payment.org_id, 'payment.voided', 'payment', v_payment.id, '{}');

  select t.profile_id into v_tenant_id
  from rent_periods rp join tenancies t on t.id = rp.tenancy_id
  where rp.id = v_payment.rent_period_id;
  perform notify_user(
    v_tenant_id, 'payment_voided', 'A payment entry was corrected',
    'Staff voided a payment entry on your rent — check your Payments screen for the current status.',
    'payment', v_payment.id
  );

  return v_payment;
end;
$$;

create or replace function resolve_dispute(
  p_payment_id uuid,
  p_outcome text,
  p_note text
)
returns payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment payments;
  v_property_id uuid;
  v_tenant_id uuid;
begin
  if p_outcome not in ('paid', 'voided') then
    raise exception 'outcome must be ''paid'' or ''voided''';
  end if;
  if p_note is null or length(trim(p_note)) = 0 then
    raise exception 'a note explaining the resolution is required';
  end if;

  select * into v_payment from payments where id = p_payment_id;
  if not found then
    raise exception 'payment % not found', p_payment_id;
  end if;
  if v_payment.status <> 'disputed' then
    raise exception 'payment is not disputed (current status: %)', v_payment.status;
  end if;

  v_property_id := property_id_for_payment(p_payment_id);
  if not is_owner_of_org((select org_id from properties where id = v_property_id)) then
    raise exception 'only the Owner can resolve a disputed payment';
  end if;

  update payments
  set status = p_outcome, dispute_resolution_note = p_note
  where id = p_payment_id
  returning * into v_payment;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_payment.org_id, 'payment.dispute_resolved', 'payment', v_payment.id,
          jsonb_build_object('outcome', p_outcome, 'note', p_note));

  select t.profile_id into v_tenant_id
  from rent_periods rp join tenancies t on t.id = rp.tenancy_id
  where rp.id = v_payment.rent_period_id;
  perform notify_user(
    v_tenant_id, 'dispute_resolved',
    case when p_outcome = 'paid' then 'Your dispute was resolved — marked as paid'
         else 'Your dispute was resolved — payment voided' end,
    p_note, 'payment', v_payment.id
  );
  if v_payment.recorded_by is not null then
    perform notify_user(
      v_payment.recorded_by, 'dispute_resolved', 'A disputed payment you recorded was resolved',
      p_note, 'payment', v_payment.id
    );
  end if;

  return v_payment;
end;
$$;

-- ---------------------------------------------------------------------
-- Complaints
-- ---------------------------------------------------------------------

create or replace function report_complaint(
  p_property_id uuid,
  p_tenancy_id uuid,
  p_category text,
  p_severity text,
  p_title text,
  p_room_label text,
  p_time_preference text,
  p_idempotency_key text default null
)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_complaint complaints;
  v_authorized boolean;
begin
  if p_tenancy_id is not null then
    select exists (select 1 from tenancies where id = p_tenancy_id and profile_id = auth.uid())
      into v_authorized;
  else
    v_authorized := is_staff_for_property(p_property_id);
  end if;
  if not v_authorized then
    raise exception 'not authorized to report this complaint';
  end if;

  if p_idempotency_key is not null then
    select * into v_complaint from complaints where idempotency_key = p_idempotency_key;
    if found then
      return v_complaint;
    end if;
  end if;

  insert into complaints (
    property_id, tenancy_id, category, severity, title, room_label,
    time_preference, reported_by, idempotency_key
  )
  values (
    p_property_id, p_tenancy_id, p_category, p_severity,
    coalesce(nullif(trim(p_title), ''), initcap(p_category) || ' issue'),
    p_room_label, p_time_preference, auth.uid(), p_idempotency_key
  )
  returning * into v_complaint;

  insert into complaint_events (complaint_id, event_type, actor_user_id)
  values (v_complaint.id, 'reported', auth.uid());

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.reported', 'complaint', v_complaint.id,
          jsonb_build_object('category', p_category, 'severity', p_severity));

  perform notify_staff_for_property(
    p_property_id, 'complaint_reported', 'New complaint: ' || v_complaint.title,
    format('%s severity, reported in %s.', initcap(p_severity), coalesce(p_room_label, 'a common area')),
    'complaint', v_complaint.id
  );

  return v_complaint;
end;
$$;

create or replace function delegate_complaint(
  p_complaint_id uuid,
  p_assignee text,
  p_note text default null
)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_complaint complaints;
  v_tenant_id uuid;
begin
  select property_id into v_property_id from complaints where id = p_complaint_id;
  if v_property_id is null then
    raise exception 'complaint % not found', p_complaint_id;
  end if;
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to delegate this complaint';
  end if;
  if p_assignee is null or length(trim(p_assignee)) = 0 then
    raise exception 'an assignee is required';
  end if;

  insert into complaint_events (complaint_id, event_type, actor_user_id, assignee, note)
  values (p_complaint_id, 'delegated', auth.uid(), p_assignee, p_note);

  select * into v_complaint from complaints where id = p_complaint_id;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.delegated', 'complaint', v_complaint.id,
          jsonb_build_object('assignee', p_assignee, 'note', p_note));

  select profile_id into v_tenant_id from tenancies where id = v_complaint.tenancy_id;
  if v_tenant_id is not null then
    perform notify_user(
      v_tenant_id, 'complaint_delegated', 'Your complaint is being handled',
      format('Assigned to %s.', p_assignee), 'complaint', v_complaint.id
    );
  end if;

  return v_complaint;
end;
$$;

create or replace function resolve_complaint(p_complaint_id uuid)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_complaint complaints;
  v_tenant_id uuid;
begin
  select property_id into v_property_id from complaints where id = p_complaint_id;
  if v_property_id is null then
    raise exception 'complaint % not found', p_complaint_id;
  end if;
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to resolve this complaint';
  end if;

  insert into complaint_events (complaint_id, event_type, actor_user_id)
  values (p_complaint_id, 'resolved', auth.uid());

  select * into v_complaint from complaints where id = p_complaint_id;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.resolved', 'complaint', v_complaint.id, '{}');

  select profile_id into v_tenant_id from tenancies where id = v_complaint.tenancy_id;
  if v_tenant_id is not null then
    perform notify_user(
      v_tenant_id, 'complaint_resolved', 'Your complaint has been resolved',
      v_complaint.title, 'complaint', v_complaint.id
    );
  end if;

  return v_complaint;
end;
$$;

create or replace function reopen_complaint(p_complaint_id uuid, p_note text default null)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_complaint complaints;
  v_authorized boolean;
begin
  select property_id into v_property_id from complaints where id = p_complaint_id;
  if v_property_id is null then
    raise exception 'complaint % not found', p_complaint_id;
  end if;

  v_authorized := tenant_owns_complaint(p_complaint_id) or is_staff_for_property(v_property_id);
  if not v_authorized then
    raise exception 'not authorized to reopen this complaint';
  end if;

  insert into complaint_events (complaint_id, event_type, actor_user_id, note)
  values (p_complaint_id, 'reopened', auth.uid(), p_note);

  select * into v_complaint from complaints where id = p_complaint_id;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.reopened', 'complaint', v_complaint.id, '{}');

  perform notify_staff_for_property(
    v_property_id, 'complaint_reopened', 'Complaint reopened: ' || v_complaint.title,
    p_note, 'complaint', v_complaint.id
  );

  return v_complaint;
end;
$$;

-- ---------------------------------------------------------------------
-- Tenancy
-- ---------------------------------------------------------------------

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

  perform notify_user(
    p_profile_id, 'tenancy_created', 'Welcome to PGKhata!',
    format('Your tenancy is now active. First rent of ₹%s is due on %s.',
           v_prorated_amount, to_char(p_move_in_date, 'DD Mon YYYY')),
    'tenancy', v_tenancy.id
  );

  return v_tenancy;
end;
$$;
