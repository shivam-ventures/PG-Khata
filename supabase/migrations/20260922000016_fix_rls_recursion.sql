-- PG Khata — migration 16: fix RLS infinite recursion between
-- tenancies <-> beds <-> rooms.
--
-- Found during negative-authorization testing (docs/backend-domain-model.md
-- §9 explicitly calls for this, not just positive-path testing): querying
-- `tenancies` as a Manager raised "infinite recursion detected in policy
-- for relation tenancies". Root cause — a real 2-way (and 3-way) cycle:
--   tenancies' manager policy   -> inline subquery into beds/rooms
--   beds' tenant policy         -> inline subquery back into tenancies
--   rooms' tenant policy        -> inline subquery into tenancies + beds
-- Every OTHER cross-table policy in migration 12 already routed through a
-- `security definer` helper (is_owner_of_org, is_manager_of_property,
-- property_id_for_rent_period, ...) specifically because a security
-- definer function's internal query runs as the function owner and does
-- NOT re-trigger RLS on the tables it touches — which is what breaks a
-- cycle. These three policies were the only ones left with a raw inline
-- subquery reaching across the same cycle; fixed the same way here.

create or replace function property_id_for_bed(target_bed_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select r.property_id from beds b join rooms r on r.id = b.room_id where b.id = target_bed_id;
$$;

create or replace function tenant_has_current_bed(target_bed_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from tenancies t
    where t.bed_id = target_bed_id and t.profile_id = auth.uid() and t.status in ('active', 'notice_period')
  );
$$;

create or replace function tenant_has_current_room(target_room_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from tenancies t join beds b on b.id = t.bed_id
    where b.room_id = target_room_id and t.profile_id = auth.uid() and t.status in ('active', 'notice_period')
  );
$$;

drop policy "manager reads scoped tenancies" on tenancies;
create policy "manager reads scoped tenancies" on tenancies for select using (
  is_manager_of_property(property_id_for_bed(bed_id))
);

drop policy "tenant reads own bed" on beds;
create policy "tenant reads own bed" on beds for select using (
  tenant_has_current_bed(id)
);

drop policy "tenant reads own room" on rooms;
create policy "tenant reads own room" on rooms for select using (
  tenant_has_current_room(id)
);

revoke execute on function property_id_for_bed(uuid) from public, anon, authenticated;
revoke execute on function tenant_has_current_bed(uuid) from public, anon, authenticated;
revoke execute on function tenant_has_current_room(uuid) from public, anon, authenticated;

comment on function property_id_for_bed(uuid) is
  'Internal RLS helper. security definer so its internal beds/rooms lookup does not re-trigger those tables'' own RLS policies — this is specifically what breaks the tenancies<->beds<->rooms cycle fixed in this migration.';
