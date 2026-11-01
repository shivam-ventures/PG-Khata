-- PG Khata — migration 5/12: the financial model (rent_periods, payments,
-- payment_allocations) and the derived per-period status view.
--
-- See docs/backend-domain-model.md §7 for the full state machine. Key
-- structural decision: a payment no longer carries "amount owed" — that's
-- rent_periods (created monthly per active tenancy). payments is only ever
-- "money that arrived," so partial/multiple payments against one period
-- are representable, which the current mock's single RentPayment row
-- (owed + paid conflated) cannot do.

create table rent_periods (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references tenancies (id) on delete restrict,
  period_month date not null, -- first-of-month, e.g. 2026-09-01
  due_date date not null,
  amount_due numeric(10, 2) not null check (amount_due > 0), -- snapshot of tenancies.rent_amount at generation time
  org_id uuid not null, -- denormalized, see §4; maintained by trigger below
  created_at timestamptz not null default now()
);

-- Idempotency for the scheduled generator (docs/backend-domain-model.md
-- §11) — a re-run must not create a second period for the same
-- tenancy/month.
create unique index rent_periods_tenancy_period_idx on rent_periods (tenancy_id, period_month);
create index rent_periods_org_id_idx on rent_periods (org_id);
create index rent_periods_due_date_idx on rent_periods (due_date);

comment on table rent_periods is
  'What''s owed for one tenancy for one month — snapshot of rent_amount at generation time, so a mid-tenancy rent change never rewrites past periods. See docs/backend-domain-model.md §7.';

create or replace function rent_periods_set_org_id()
returns trigger
language plpgsql
as $$
begin
  select t.org_id into new.org_id from tenancies t where t.id = new.tenancy_id;
  if new.org_id is null then
    raise exception 'tenancy % does not resolve to an org', new.tenancy_id;
  end if;
  return new;
end;
$$;

create trigger rent_periods_set_org_id_trigger
  before insert on rent_periods
  for each row execute function rent_periods_set_org_id();

-- "Money that arrived." status here is the settlement state of ONE payment
-- attempt, not the period as a whole (see rent_period_status view below,
-- which is what the UI actually reads). 'voided' is a terminal status a
-- payment moves to via correction/dispute-resolution — the row is kept
-- (never deleted, per docs/backend-domain-model.md §5), it's just excluded
-- from "what's the period's current state" once voided.
create table payments (
  id uuid primary key default gen_random_uuid(),
  rent_period_id uuid not null references rent_periods (id) on delete restrict,
  amount numeric(10, 2) not null check (amount > 0),
  method text not null check (method in ('cash', 'upi', 'card', 'bank_transfer')),
  recorded_by uuid not null references profiles (id),
  -- true only for the tenant's own in-app payment (recordSelfPayment) — see
  -- the payment state machine: this is the ONE path that settles straight
  -- to 'paid', because it's the one path actually verified by the
  -- transaction itself rather than taken on staff's word. Every
  -- staff-recorded payment, any method including UPI shown to have reached
  -- the owner, starts at 'awaiting_confirmation' — this is the specific
  -- trust-model rule confirmed for this product; do not "simplify" it.
  is_self_recorded boolean not null default false,
  status text not null default 'awaiting_confirmation'
    check (status in ('awaiting_confirmation', 'paid', 'disputed', 'voided')),
  gateway_ref text, -- null for cash/staff-claimed; a real ref once a payment gateway exists (not this phase)
  dispute_resolution_note text, -- required when an Owner resolves a dispute either direction, see §12.6
  idempotency_key text, -- client-generated, see docs/backend-domain-model.md §11 (duplicate-tap/retry safety)
  org_id uuid not null, -- denormalized, see §4
  paid_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger payments_set_updated_at
  before update on payments
  for each row execute function set_updated_at();

create unique index payments_idempotency_key_idx on payments (idempotency_key) where idempotency_key is not null;
create index payments_rent_period_id_idx on payments (rent_period_id);
create index payments_org_id_idx on payments (org_id);
-- The Owner/Manager payment screens' primary read pattern: pending cash
-- confirmations, disputes needing resolution — both are small, hot subsets
-- of a table that will otherwise grow to years of history.
create index payments_awaiting_confirmation_idx on payments (org_id) where status = 'awaiting_confirmation';
create index payments_disputed_idx on payments (org_id) where status = 'disputed';

comment on table payments is
  'One row per payment ATTEMPT (never deleted — a mistake is corrected by moving status to voided, not by removing the row, so what staff actually entered is never silently erased). See docs/backend-domain-model.md §5, §7.';

create or replace function payments_set_org_id()
returns trigger
language plpgsql
as $$
begin
  select rp.org_id into new.org_id from rent_periods rp where rp.id = new.rent_period_id;
  if new.org_id is null then
    raise exception 'rent_period % does not resolve to an org', new.rent_period_id;
  end if;
  return new;
end;
$$;

create trigger payments_set_org_id_trigger
  before insert on payments
  for each row execute function payments_set_org_id();

-- Only needed once a single payment can cover more than one rent_period
-- (an advance/lump payment) or a rent_period needs more than one payment
-- (a partial payment then a top-up). Modeled now (cheap), not yet used by
-- any RPC beyond the trivial 1:1 case — see docs/backend-domain-model.md §7.
create table payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references payments (id) on delete restrict,
  rent_period_id uuid not null references rent_periods (id) on delete restrict,
  amount_allocated numeric(10, 2) not null check (amount_allocated > 0),
  created_at timestamptz not null default now()
);

create index payment_allocations_payment_id_idx on payment_allocations (payment_id);
create index payment_allocations_rent_period_id_idx on payment_allocations (rent_period_id);

comment on table payment_allocations is
  'Junction for a payment covering (or partially covering) one or more rent_periods. Every current write path creates exactly one 1:1 allocation row per payment — the schema is ready for the harder multi-period case without any current behavior changing. See docs/backend-domain-model.md §7.';

-- What the UI actually reads: one row per rent_period, with its CURRENT
-- effective status derived from the latest non-voided payment attempt
-- against it (a void makes the system "forget" that attempt for status
-- purposes, while the row itself stays for history). Mirrors the current
-- Flutter PaymentStatus enum exactly (pending/overdue/awaiting_confirmation/
-- paid/disputed) — see docs/backend-domain-model.md §7.
create or replace view rent_period_status as
select
  rp.id as rent_period_id,
  rp.tenancy_id,
  rp.period_month,
  rp.due_date,
  rp.amount_due,
  rp.org_id,
  case
    when latest.status is not null then latest.status
    when rp.due_date < current_date then 'overdue'
    else 'pending'
  end as status,
  latest.id as latest_payment_id,
  latest.amount as paid_amount,
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

comment on view rent_period_status is
  'The read model the Owner/Manager/Tenant payment screens actually use — one row per period, current status derived live. Never stored as a column anywhere.';
