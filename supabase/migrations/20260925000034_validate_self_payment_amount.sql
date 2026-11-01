-- PG Khata — migration 34: reject a self-recorded payment that doesn't
-- match what's actually owed.
--
-- Bug found during the pre-launch audit (2026-09-25): record_self_payment
-- accepted whatever `p_amount` the client sent and always settled straight
-- to 'paid' with no comparison against rent_periods.amount_due — combined
-- with the tenant "Pay Rent" UI being a simulated UPI/card flow (no real
-- gateway), a tenant could self-record ₹1 against any rent period and have
-- it read as fully paid. record_payment/confirm_payment (the staff-recorded
-- path) are deliberately left permissive here — partial and advance/lump
-- payments recorded by staff and confirmed by the tenant are legitimate,
-- real-world cash-handling scenarios (see payment_allocations' own comment
-- in migration 5) and the tenant still has to explicitly confirm or dispute
-- what staff claim, so there's a human check in that path. record_self_payment
-- has no such check — it's the tenant paying themselves, unattended — so it
-- is the one path that must match exactly what's actually still owed,
-- computed from confirmed payments only (rent_period_remaining_balance,
-- migration 33), not trust the client's claimed amount.

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
  v_remaining numeric;
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

  if p_amount is null or p_amount <= 0 then
    raise exception 'invalid_amount: amount must be greater than zero';
  end if;

  v_remaining := rent_period_remaining_balance(p_rent_period_id);
  if v_remaining <= 0 then
    raise exception 'already_paid: rent period % is already fully paid', p_rent_period_id;
  end if;
  if p_amount <> v_remaining then
    raise exception 'amount_mismatch: % does not match the amount owed (%)', p_amount, v_remaining;
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

comment on function record_self_payment(uuid, text, numeric, text) is
  'The tenant''s own in-app payment — settles straight to paid because it is unattended (no staff review step), so p_amount MUST exactly equal rent_period_remaining_balance() or this raises amount_mismatch/already_paid. See migration 34. Do not loosen this the way record_payment/confirm_payment deliberately are — those have a human confirm/dispute step this path does not.';
