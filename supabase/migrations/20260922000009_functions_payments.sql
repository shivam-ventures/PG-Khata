-- PG Khata — migration 9/12: authorization helpers + the payment state
-- machine as Postgres functions.
--
-- Every payment write happens through one of these, never a raw client
-- INSERT/UPDATE on payments (migration 12's RLS grants SELECT only to
-- authenticated roles on payments/rent_periods) — see
-- docs/backend-domain-model.md §7/§9/§18: authorization ("can this user
-- touch this property's data") and business validation ("is this status
-- transition legal") both live here, in one place, not split between RLS
-- and application code.

create or replace function is_owner_of_org(target_org_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from organizations where id = target_org_id and owner_user_id = auth.uid()
  );
$$;

create or replace function is_manager_of_property(target_property_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from property_managers
    where property_id = target_property_id and manager_user_id = auth.uid() and unassigned_at is null
  );
$$;

create or replace function is_staff_for_property(target_property_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select is_owner_of_org((select org_id from properties where id = target_property_id))
      or is_manager_of_property(target_property_id);
$$;

create or replace function property_id_for_rent_period(target_rent_period_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select r.property_id
  from rent_periods rp
  join tenancies t on t.id = rp.tenancy_id
  join beds b on b.id = t.bed_id
  join rooms r on r.id = b.room_id
  where rp.id = target_rent_period_id;
$$;

create or replace function property_id_for_payment(target_payment_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select property_id_for_rent_period(rent_period_id) from payments where id = target_payment_id;
$$;

create or replace function tenant_owns_rent_period(target_rent_period_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from rent_periods rp
    join tenancies t on t.id = rp.tenancy_id
    where rp.id = target_rent_period_id and t.profile_id = auth.uid()
  );
$$;

create or replace function tenant_owns_payment(target_payment_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from payments p
    join rent_periods rp on rp.id = p.rent_period_id
    join tenancies t on t.id = rp.tenancy_id
    where p.id = target_payment_id and t.profile_id = auth.uid()
  );
$$;

comment on function is_staff_for_property(uuid) is
  'Owner of the org that owns this property, OR a Manager actively assigned to it. The authorization check every payment/complaint RPC starts with.';

-- Staff-recorded payment, any method — ALWAYS awaiting_confirmation. This
-- is the specific, product-confirmed trust-model rule: only a tenant's own
-- verified in-app payment (record_self_payment) settles instantly. Do not
-- special-case UPI or any other method here.
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
      return v_payment; -- retried request (duplicate tap / network retry) — return the original result, don't double-record
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

  return v_payment;
end;
$$;

-- The tenant's own in-app payment — settles straight to 'paid', because
-- it's the one path actually verified by the transaction itself.
create or replace function record_self_payment(
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
  v_payment payments;
begin
  if not tenant_owns_rent_period(p_rent_period_id) then
    raise exception 'not authorized to pay this rent period';
  end if;

  if p_idempotency_key is not null then
    select * into v_payment from payments where idempotency_key = p_idempotency_key;
    if found then
      return v_payment;
    end if;
  end if;

  insert into payments (rent_period_id, amount, method, recorded_by, is_self_recorded, status, idempotency_key)
  values (p_rent_period_id, p_amount, p_method, auth.uid(), true, 'paid', p_idempotency_key)
  returning * into v_payment;

  insert into payment_allocations (payment_id, rent_period_id, amount_allocated)
  values (v_payment.id, p_rent_period_id, p_amount);

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_payment.org_id, 'payment.self_recorded', 'payment', v_payment.id,
          jsonb_build_object('method', p_method, 'amount', p_amount));

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

  return v_payment;
end;
$$;

-- The "staff made an honest mistake" correction path — refuses to touch an
-- already-disputed payment on purpose (see resolve_dispute below, the
-- sanctioned way to close those out per docs/backend-domain-model.md §12.6).
create or replace function void_payment(p_payment_id uuid)
returns payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment payments;
  v_property_id uuid;
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

  return v_payment;
end;
$$;

-- Owner-only override of a disputed payment, either direction, with a
-- required note — docs/backend-domain-model.md §12.6, resolved 2026-09-22.
-- The Manager who may have recorded the original disputed claim cannot
-- adjudicate their own dispute.
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

  return v_payment;
end;
$$;

-- Scheduled (pg_cron / an external scheduler using the service role), not
-- client-invoked — idempotent via rent_periods' own unique (tenancy_id,
-- period_month) index, so a re-run for the same month is a safe no-op.
-- The auth.uid() check below simply refuses to run under a normal user
-- session (only a service-role context, which has no user JWT, may call
-- it) — see docs/backend-domain-model.md §11, §26.
create or replace function generate_rent_periods()
returns setof rent_periods
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period_month date := date_trunc('month', current_date)::date;
begin
  if auth.uid() is not null then
    raise exception 'generate_rent_periods is scheduled/service-role only';
  end if;

  return query
  insert into rent_periods (tenancy_id, period_month, due_date, amount_due)
  select
    t.id,
    v_period_month,
    (v_period_month + (t.rent_due_day - 1) * interval '1 day')::date,
    t.rent_amount
  from tenancies t
  where t.status = 'active'
  on conflict (tenancy_id, period_month) do nothing
  returning *;
end;
$$;

comment on function generate_rent_periods() is
  'Run monthly by a scheduler (pg_cron or an external cron hitting this via the service role) — creates this month''s rent_periods for every active tenancy that doesn''t already have one. Never called by the Flutter app directly.';
