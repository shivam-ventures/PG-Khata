-- PG Khata — migration 23: a Tenant has no SELECT policy on `properties`
-- at all (migration 12 only granted Owner/Manager access) — caught while
-- verifying Complaints: a Tenant querying complaints with an embedded
-- `properties!inner(name)` got back zero rows, because PostgREST's !inner
-- embed excludes the parent row when the child fails RLS. The same gap
-- would break Tenant Home (needs the PG name/address) once it's wired.
-- Mirrors the existing "tenant reads own room"/"tenant reads own bed"
-- policy shape exactly.

create policy "tenant reads own property" on properties for select using (
  exists (
    select 1 from tenancies t
    join beds b on b.id = t.bed_id
    join rooms r on r.id = b.room_id
    where r.property_id = properties.id and t.profile_id = auth.uid() and t.status = 'active'
  )
);
