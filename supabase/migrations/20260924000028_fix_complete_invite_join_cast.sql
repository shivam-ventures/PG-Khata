-- PG Khata — migration 28: fix complete_invite_join's call to
-- create_tenancy_for_profile.
--
-- Found while live-testing the invite-link join flow end to end for the
-- first time (all earlier verification only exercised resolve-invite /
-- create_invite_link, never a full completed join): the call
--   create_tenancy_for_profile(auth.uid(), v_invite.bed_id, v_rent, 5,
--                               null, current_date, 'self_joined', null)
-- has been broken since it was first written in migration 11. The bare
-- literal `5` defaults to `integer`, but create_tenancy_for_profile's
-- p_rent_due_day parameter is `smallint` — and Postgres's function-overload
-- resolution only considers *implicit* casts, while int4 -> int2 is only
-- registered as an *assignment* cast. So Postgres reports "function ...
-- does not exist" even though a same-named function with a compatible
-- smallint parameter genuinely exists. Every self-registration via an
-- invite link has therefore failed at the final "confirm your name" step
-- since the feature was built. Fixed by casting the literal explicitly at
-- the one call site, rather than loosening create_tenancy_for_profile's
-- own parameter type (every other caller passes an already-typed value).

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

  select right(regexp_replace(phone, '\D', '', 'g'), 10) into v_phone
  from auth.users where id = auth.uid();

  insert into profiles (id, role, full_name, phone)
  values (auth.uid(), 'tenant', p_full_name, coalesce(v_phone, ''))
  on conflict (id) do update set full_name = excluded.full_name;

  select rent_per_bed into v_rent
  from beds b join rooms r on r.id = b.room_id
  where b.id = v_invite.bed_id;

  v_tenancy := create_tenancy_for_profile(
    auth.uid(), v_invite.bed_id, v_rent, 5::smallint, null::numeric,
    current_date, 'self_joined', null::uuid
  );

  update tenant_invite_links
  set used_at = now(), used_by_tenancy_id = v_tenancy.id
  where id = v_invite.id;

  return v_tenancy;
end;
$$;
