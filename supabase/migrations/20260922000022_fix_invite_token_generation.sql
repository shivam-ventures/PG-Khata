-- PG Khata — migration 22: fix create_invite_link's token generation.
--
-- gen_random_bytes() is from pgcrypto, which Supabase installs into the
-- `extensions` schema, not `public` — this function is `security definer`
-- with `set search_path = public`, so pgcrypto's functions were never in
-- scope and every call failed with "function gen_random_bytes(integer)
-- does not exist" (caught while verifying the Onboarding invite flow).
-- gen_random_uuid() is a core Postgres builtin (no extension needed) and
-- gives the same ~122 bits of randomness, so it sidesteps the schema issue
-- entirely rather than schema-qualifying the pgcrypto call.

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
  values (p_bed_id, replace(gen_random_uuid()::text, '-', ''), auth.uid())
  returning * into v_invite;

  return v_invite;
end;
$$;
