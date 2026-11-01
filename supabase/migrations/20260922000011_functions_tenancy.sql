-- PG Khata — migration 11/12: tenancy lifecycle as Postgres functions —
-- move-in, transfer, move-out, invite links, and the invite-join flow.
--
-- Note on "Add Tenant" for a person who has never opened the app: that
-- specific case needs to pre-provision a real auth.users row for someone
-- who hasn't signed in yet, which is a Supabase Admin API operation, not
-- something a plain Postgres function can/should do — see the
-- `add-tenant` Edge Function (supabase/functions/add-tenant/) which
-- creates/finds the auth user via the service role, then calls
-- create_tenancy_for_profile below. Every other tenancy operation here
-- (assigning an already-signed-up person, self-joining via invite link,
-- transferring, moving out) only ever touches profiles that already exist,
-- so those stay plain RPCs.

-- Internal helper, not directly callable by clients (see grants in
-- migration 12) — every public-facing RPC below that actually creates a
-- tenancy goes through this one function, so the partial unique index
-- from migration 4 (tenancies_one_active_per_bed_idx) is the single place
-- double-booking gets caught, and every caller gets the same audit trail.
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

  return v_tenancy;
end;
$$;

-- Staff assigning an already-signed-up person (they've opened the app and
-- verified their phone at least once, so a profiles row exists) to a bed —
-- the real-backend equivalent of assignPendingTenant, without requiring
-- the specific "self-registered, needs a bed" list the current mock's
-- PendingTenant illustrates (that list's own backing is still open per
-- docs/backend-domain-model.md §12.3).
create or replace function assign_tenant_to_bed(
  p_profile_id uuid,
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
  v_property_id uuid;
begin
  select r.property_id into v_property_id
  from beds b join rooms r on r.id = b.room_id
  where b.id = p_bed_id;

  if v_property_id is null then
    raise exception 'bed % not found', p_bed_id;
  end if;
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to assign a tenant to this property';
  end if;

  return create_tenancy_for_profile(
    p_profile_id, p_bed_id, p_rent_amount, p_rent_due_day, p_deposit_amount,
    p_move_in_date, 'staff_created', auth.uid()
  );
end;
$$;

-- Called by the tenant THEMSELF, immediately after they verify their own
-- phone OTP via Supabase Auth directly (not through this function — the
-- Flutter client calls Supabase Auth's own signInWithOtp/verifyOtp, which
-- is what sets auth.uid() before this ever runs). No Admin API needed here
-- because the tenant is provisioning their own account, not being
-- provisioned by someone else.
create or replace function complete_invite_join(
  p_token text,
  p_full_name text
)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite tenant_invite_links;
  v_rent numeric;
  v_phone text;
  v_tenancy tenancies;
begin
  select * into v_invite from tenant_invite_links where token = p_token;
  if not found then
    raise exception 'invite not found';
  end if;
  if v_invite.used_at is not null then
    raise exception 'invite already used';
  end if;
  if v_invite.expires_at < now() then
    raise exception 'invite expired';
  end if;

  select phone into v_phone from auth.users where id = auth.uid();

  insert into profiles (id, role, full_name, phone)
  values (auth.uid(), 'tenant', p_full_name, coalesce(v_phone, ''))
  on conflict (id) do update set full_name = excluded.full_name;

  select rent_per_bed into v_rent
  from beds b join rooms r on r.id = b.room_id
  where b.id = v_invite.bed_id;

  v_tenancy := create_tenancy_for_profile(
    auth.uid(), v_invite.bed_id, v_rent, 5, null, current_date, 'self_joined', null
  );

  update tenant_invite_links
  set used_at = now(), used_by_tenancy_id = v_tenancy.id
  where id = v_invite.id;

  return v_tenancy;
end;
$$;

comment on function complete_invite_join(text, text) is
  'The one atomic replacement for the current mock''s 3 separate sequential calls (addTenant + occupyBed + consumeInvite) — see docs/backend-domain-model.md §11 on why that sequence needs to be one transaction.';

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

  update tenancies set status = 'moved_out', move_out_date = current_date
  where id = p_tenancy_id
  returning * into v_tenancy;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_tenancy.org_id, 'tenancy.moved_out', 'tenancy', v_tenancy.id, '{}');

  return v_tenancy;
end;
$$;

comment on function move_out_tenant(uuid) is
  'Closes the tenancy (status -> moved_out) which is ALSO how the bed becomes vacant again — bed_occupancy is derived, so this single update is the whole operation. The current mock''s move-out bug (it never actually freed the bed in Rooms data) cannot happen here by construction.';

-- Atomic: closes the old tenancy and opens a new one in a single
-- transaction, so a bed is never briefly claimable by two people mid-
-- transfer (docs/backend-domain-model.md §8, §11).
create or replace function transfer_tenancy(
  p_tenancy_id uuid,
  p_new_bed_id uuid,
  p_new_rent_amount numeric default null
)
returns tenancies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old tenancies;
  v_new tenancies;
  v_old_property_id uuid;
  v_new_property_id uuid;
begin
  select * into v_old from tenancies where id = p_tenancy_id;
  if not found then
    raise exception 'tenancy % not found', p_tenancy_id;
  end if;
  if v_old.status <> 'active' then
    raise exception 'only an active tenancy can be transferred';
  end if;

  select r.property_id into v_old_property_id from beds b join rooms r on r.id = b.room_id where b.id = v_old.bed_id;
  select r.property_id into v_new_property_id from beds b join rooms r on r.id = b.room_id where b.id = p_new_bed_id;

  if not (is_staff_for_property(v_old_property_id) and is_staff_for_property(v_new_property_id)) then
    raise exception 'not authorized to transfer this tenancy';
  end if;

  update tenancies set status = 'moved_out', move_out_date = current_date where id = p_tenancy_id;

  v_new := create_tenancy_for_profile(
    v_old.profile_id, p_new_bed_id, coalesce(p_new_rent_amount, v_old.rent_amount),
    v_old.rent_due_day, v_old.security_deposit_amount, current_date, 'staff_created', auth.uid()
  );

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_new.org_id, 'tenancy.transferred', 'tenancy', v_new.id,
          jsonb_build_object('from_tenancy_id', v_old.id, 'from_bed_id', v_old.bed_id, 'to_bed_id', p_new_bed_id));

  return v_new;
end;
$$;

create or replace function create_invite_link(p_bed_id uuid)
returns tenant_invite_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_invite tenant_invite_links;
begin
  select r.property_id into v_property_id from beds b join rooms r on r.id = b.room_id where b.id = p_bed_id;
  if v_property_id is null then
    raise exception 'bed % not found', p_bed_id;
  end if;
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to create an invite for this property';
  end if;

  insert into tenant_invite_links (bed_id, token, created_by)
  values (p_bed_id, encode(gen_random_bytes(16), 'hex'), auth.uid())
  returning * into v_invite;

  return v_invite;
end;
$$;
