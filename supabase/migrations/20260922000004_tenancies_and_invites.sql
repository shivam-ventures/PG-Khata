-- PG Khata — migration 4/12: tenancies (the identity/tenancy split) and
-- invite links.
--
-- See docs/backend-domain-model.md §8 (tenancy model — simplified from the
-- pre-pivot's 6-state machine to match what's actually built today, while
-- staying extensible to the richer flow later), §3 (the anti-double-
-- booking invariant), §12.4 (persisted invite links, not derived strings).

create table tenancies (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id), -- WHO — the tenant's identity
  bed_id uuid not null references beds (id),          -- WHERE
  status text not null default 'active'
    check (status in ('active', 'notice_period', 'moved_out')),
  source text not null default 'staff_created'
    check (source in ('staff_created', 'self_joined')),
  move_in_date date not null default current_date,
  move_out_date date,
  rent_amount numeric(10, 2) not null check (rent_amount > 0),
  rent_due_day smallint not null default 5 check (rent_due_day between 1 and 28),
  security_deposit_amount numeric(10, 2),
  security_deposit_collected_at timestamptz,
  created_by uuid references profiles (id), -- null when source = 'self_joined'
  -- Denormalized for RLS/query performance only (docs/backend-domain-model.md
  -- §4) — the source of truth is still the bed_id -> room -> property -> org
  -- chain; this column is maintained by the trigger below, never written
  -- directly by application code.
  org_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger tenancies_set_updated_at
  before update on tenancies
  for each row execute function set_updated_at();

-- The actual anti-double-booking mechanism (docs/backend-domain-model.md
-- §3, §6, §8): at most one ACTIVE tenancy per bed at any time. This is
-- enforced here, not just assumed by application code — a real Postgres
-- constraint that no client bug or race can bypass.
create unique index tenancies_one_active_per_bed_idx
  on tenancies (bed_id)
  where status = 'active';

create index tenancies_profile_id_idx on tenancies (profile_id);
create index tenancies_org_id_idx on tenancies (org_id);
create index tenancies_bed_id_idx on tenancies (bed_id);

comment on table tenancies is
  'One row per stay. A tenant moving beds/rooms/properties is a new row here with the old one flipped to moved_out — this table IS the move history, by construction; no separate history table needed. Status intentionally has only 3 values today (matches the current Flutter TenantStatus exactly) — richer pre-pivot states (pending_approval, pending_profile) can be added later as more allowed values without touching this table''s shape. See docs/backend-domain-model.md §8.';

-- Resolves org_id from the bed this tenancy is being created/moved against,
-- so application code never has to (and never can, incorrectly) set it by
-- hand — this is what keeps the denormalized column from ever disagreeing
-- with the real FK chain.
create or replace function tenancies_set_org_id()
returns trigger
language plpgsql
as $$
begin
  select p.org_id into new.org_id
  from beds b
  join rooms r on r.id = b.room_id
  join properties p on p.id = r.property_id
  where b.id = new.bed_id;

  if new.org_id is null then
    raise exception 'bed % does not resolve to a property/org', new.bed_id;
  end if;

  return new;
end;
$$;

create trigger tenancies_set_org_id_trigger
  before insert or update of bed_id on tenancies
  for each row execute function tenancies_set_org_id();

-- Bed occupancy — always derived, never stored (docs/backend-domain-model.md
-- §6). This is the direct analogue of the Flutter app's own
-- propertyMetricsProvider pattern, at the single-bed level.
create or replace view bed_occupancy as
select
  b.id as bed_id,
  b.room_id,
  t.id as active_tenancy_id,
  t.profile_id as active_tenant_profile_id,
  (t.id is not null) as is_occupied
from beds b
left join tenancies t on t.bed_id = b.id and t.status = 'active';

comment on view bed_occupancy is
  'Whether a bed is vacant, derived live from tenancies — never a stored column. See docs/backend-domain-model.md §6.';

-- Persisted, expiring, revocable invite links — replaces the current mock's
-- derived-from-string-pattern token (docs/backend-domain-model.md §12.4).
create table tenant_invite_links (
  id uuid primary key default gen_random_uuid(),
  bed_id uuid not null references beds (id) on delete cascade,
  token text not null unique,
  created_by uuid not null references profiles (id),
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  used_by_tenancy_id uuid references tenancies (id),
  created_at timestamptz not null default now()
);

create index tenant_invite_links_bed_id_idx on tenant_invite_links (bed_id) where used_at is null;
create unique index tenant_invite_links_token_idx on tenant_invite_links (token);

comment on table tenant_invite_links is
  'Bed-specific invite links, e.g. Manager Rooms'' "Invite via link" action. Persisted and revocable (expires_at/used_at) instead of the mock''s literal "propertyId-room-bed" string token. Resolved server-side (an unauthenticated person cannot read this table via RLS) — see docs/backend-domain-model.md §9/§12.4.';
