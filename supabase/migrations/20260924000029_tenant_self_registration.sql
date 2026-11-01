-- PG Khata — migration 29: direct tenant self-registration.
--
-- The second onboarding path the product backlog asked for, alongside the
-- invite-link flow: someone with no invite picks a PG themselves and
-- signals interest, landing in the exact "SELF-REGISTERED — NEEDS A BED"
-- pending bucket the Owner/Manager Tenants screens and
-- `AddOwnerTenantDialog`'s assign-mode were already built for
-- (`PendingTenant`/`assignPendingTenant` in the Flutter app) — that UI and
-- `assign_tenant_to_bed` below have existed since migration 11 waiting for
-- a real caller; `SupabaseTenantsRepository.fetchPendingTenants` has
-- returned `Ok([])` with a comment saying exactly that. This is
-- deliberately simpler than the 2026-09-15 decision log's "browse every
-- bed, claim one atomically" sketch: the person picks a *property*, not a
-- specific bed, and staff — who already knows real vacancy, move-in
-- timing and what to actually charge — picks the bed and confirms rent,
-- exactly like a staff-created tenant. No race condition to design around
-- because nothing is claimed until staff acts.

create table tenant_signup_interests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  property_id uuid not null references properties (id),
  created_at timestamptz not null default now(),
  -- One open interest at a time — re-registering just updates which PG.
  unique (profile_id)
);

alter table tenant_signup_interests enable row level security;

create policy "staff reads their property's signups" on tenant_signup_interests
  for select using (is_staff_for_property(property_id));

comment on table tenant_signup_interests is
  'A signed-up-but-unplaced tenant''s stated interest in one PG — backs the "SELF-REGISTERED — NEEDS A BED" list. Resolved (deleted) by assign_pending_tenant once staff assigns a real bed.';

-- A minimal public window over `properties`, safe for a signed-out
-- picker — same pattern as `resolve-invite`'s Edge Function, but plain
-- columns are enough here since nothing sensitive is exposed.
create or replace view public_property_listings as
select
  p.id as property_id,
  p.name,
  p.address,
  count(b.id) filter (where not exists (
    select 1 from tenancies t
    where t.bed_id = b.id and t.status in ('active', 'notice_period')
  )) as vacant_bed_count
from properties p
join rooms r on r.property_id = p.id and r.archived_at is null
join beds b on b.room_id = r.id and b.archived_at is null
group by p.id, p.name, p.address;

grant select on public_property_listings to anon, authenticated;

comment on view public_property_listings is
  'Public discovery surface for direct self-registration — every property with its live vacant-bed count, no auth required. Runs with the view owner''s privileges (Postgres''s normal view behavior), which is how it sees past properties''/rooms''/beds'' own RLS to expose just these columns.';

create or replace function self_register_tenant(
  p_full_name text,
  p_property_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_interest tenant_signup_interests;
begin
  if not exists (select 1 from properties where id = p_property_id) then
    raise exception 'property % not found', p_property_id;
  end if;

  select right(regexp_replace(phone, '\D', '', 'g'), 10) into v_phone
  from auth.users where id = auth.uid();

  insert into profiles (id, role, full_name, phone)
  values (auth.uid(), 'tenant', p_full_name, coalesce(v_phone, ''))
  on conflict (id) do update set full_name = excluded.full_name;

  insert into tenant_signup_interests (profile_id, property_id)
  values (auth.uid(), p_property_id)
  on conflict (profile_id) do update
    set property_id = excluded.property_id, created_at = now()
  returning * into v_interest;

  perform notify_staff_for_property(
    p_property_id, 'tenant_signup', 'New self-registration: ' || p_full_name,
    'Waiting for you to assign a bed.', 'tenant_signup_interest', v_interest.id
  );
end;
$$;

-- Staff resolving a pending signup — thin wrapper around the existing
-- assign_tenant_to_bed (migration 11), which already does the
-- authorization check, tenancy creation, proration and notifications;
-- this just also clears the now-resolved signup interest.
create or replace function assign_pending_tenant(
  p_interest_id uuid,
  p_bed_id uuid,
  p_rent_amount numeric,
  p_rent_due_day smallint default 5,
  p_deposit_amount numeric default null,
  p_move_in_date date default current_date
)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_interest tenant_signup_interests;
  v_tenancy tenancies;
begin
  select * into v_interest from tenant_signup_interests where id = p_interest_id;
  if not found then
    raise exception 'pending signup % not found', p_interest_id;
  end if;

  v_tenancy := assign_tenant_to_bed(
    v_interest.profile_id, p_bed_id, p_rent_amount, p_rent_due_day,
    p_deposit_amount, p_move_in_date
  );

  delete from tenant_signup_interests where id = p_interest_id;

  return v_tenancy;
end;
$$;
