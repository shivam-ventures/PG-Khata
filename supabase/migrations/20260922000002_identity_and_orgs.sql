-- PG Khata — migration 2/12: identity, organizations, manager assignments.
--
-- See docs/backend-domain-model.md §1-5, §12.1 (Manager<->Property is
-- many-to-many, confirmed 2026-09-22) and §12.7 (super_admin intentionally
-- omitted from the role check for now — trivial to add later).

-- One row per authenticated person, created alongside auth.users. Trimmed
-- to what the current Flutter AppUser needs (id/name/phone/role) — no
-- org_id here: an Owner's org is looked up via `organizations.owner_user_id`,
-- a Manager's properties via `property_managers`, and a Tenant is never
-- org-scoped at all (see the identity/tenancy split below).
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'manager', 'tenant')),
  full_name text not null default '',
  phone text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on profiles
  for each row execute function set_updated_at();

comment on table profiles is
  'One row per auth.users person. role is fixed at signup time in this phase (no self-service role switching). Org membership is derived (organizations.owner_user_id for an Owner, property_managers for a Manager) rather than stored here, because a Tenant is never org-scoped at all — see tenant_profiles/tenancies.';

-- Tenant-only identity fields that persist across every tenancy this person
-- ever has, at any org. Created the first time a tenant profile is touched
-- (lazily), not required at signup.
create table tenant_profiles (
  id uuid primary key references profiles (id) on delete cascade,
  emergency_contact_name text,
  emergency_contact_phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger tenant_profiles_set_updated_at
  before update on tenant_profiles
  for each row execute function set_updated_at();

comment on table tenant_profiles is
  'Tenant identity that survives a move to a different bed, property, or even a different owner''s organization over time — see docs/backend-domain-model.md §8 and §12.2.';

-- One organization per Owner account (a "business," in effect). An Owner's
-- own profile is found via organizations.owner_user_id, not a column on
-- profiles, so a person could in principle own more than one org later
-- without a schema change (not built now, just not foreclosed).
create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_user_id uuid not null references profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger organizations_set_updated_at
  before update on organizations
  for each row execute function set_updated_at();

create index organizations_owner_user_id_idx on organizations (owner_user_id);

comment on table organizations is
  'One per Owner''s business. Every property, room, bed, tenancy, payment and complaint is ultimately scoped to one of these — see the ownership model in docs/backend-domain-model.md §4.';

-- Many-to-many: a Manager can be assigned to several properties, and a
-- property can (in principle) have more than one Manager — confirmed as
-- the real product rule 2026-09-22 (docs/backend-domain-model.md §12.1),
-- even though today's Flutter UI only ever exercises the single-manager
-- case. Kept as a real join table rather than a single FK for exactly that
-- reason: cheap to build correctly now, expensive to retrofit later.
create table property_managers (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null, -- FK added in the properties migration (avoids a forward reference)
  manager_user_id uuid not null references profiles (id),
  assigned_at timestamptz not null default now(),
  assigned_by uuid references profiles (id),
  unassigned_at timestamptz, -- soft-unassign; row is kept for accountability history, see §5
  created_at timestamptz not null default now()
);

comment on table property_managers is
  'Many-to-many Manager<->Property assignment. unassigned_at is set rather than deleting the row, so "who managed this property when" survives a reassignment — see docs/backend-domain-model.md §5.';

-- Helper used throughout RLS policies (migration 12): the calling user's
-- own profile row, looked up once per policy check. security definer so it
-- can read `profiles` even from a policy on a different table that hasn't
-- itself granted select yet; stable so Postgres can cache it within one
-- statement instead of re-running it per row.
create or replace function auth_profile()
returns profiles
language sql
security definer
stable
set search_path = public
as $$
  select * from profiles where id = auth.uid();
$$;

comment on function auth_profile() is
  'The calling user''s own profiles row. Used by every RLS policy in migration 12 instead of repeating a 5-way join by hand in each one.';
