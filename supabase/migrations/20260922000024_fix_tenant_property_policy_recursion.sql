-- PG Khata — migration 24: fix infinite recursion from migration 23's new
-- "tenant reads own property" policy.
--
-- Same root cause as migration 16's tenancies<->beds<->rooms cycle: the
-- policy's raw inline subquery (tenancies -> beds -> rooms -> properties)
-- runs as the querying role, so it re-triggers rooms'/beds' OWNER policies,
-- which reach back into properties via a plain subquery, back into my new
-- tenant policy, forever. Fixed the same way — route through a `security
-- definer` helper, whose internal query does not re-trigger RLS on the
-- tables it touches.

create or replace function tenant_has_current_property(target_property_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from tenancies t join beds b on b.id = t.bed_id join rooms r on r.id = b.room_id
    where r.property_id = target_property_id and t.profile_id = auth.uid() and t.status in ('active', 'notice_period')
  );
$$;

grant execute on function tenant_has_current_property(uuid) to authenticated;

drop policy "tenant reads own property" on properties;
create policy "tenant reads own property" on properties for select using (
  tenant_has_current_property(id)
);
