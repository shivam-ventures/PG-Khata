-- PG Khata — migration 21: normalize the phone stored on a self-joined
-- tenant's profile.
--
-- profiles.phone is bare-10-digit everywhere else in the app (seeded
-- Owner/Manager/Tenant profiles, and the add-tenant Edge Function's
-- staff-created tenants) — auth.users.phone is E.164 (with the +91 country
-- code) since that's what Supabase Auth's phone provider requires. The
-- original complete_invite_join copied auth.users.phone straight across,
-- so a self-joined tenant's profiles.phone would carry the country code
-- while every other profile doesn't — breaking the phone-match this app
-- uses in a couple of places (e.g. currentTenantRecordProvider's fallback).

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
    auth.uid(), v_invite.bed_id, v_rent, 5, null, current_date, 'self_joined', null
  );

  update tenant_invite_links
  set used_at = now(), used_by_tenancy_id = v_tenancy.id
  where id = v_invite.id;

  return v_tenancy;
end;
$$;
