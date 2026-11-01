-- PG Khata — migration 38: id-documents Storage bucket + policies.
--
-- Gap found during the pre-launch audit (2026-09-25): id_documents (the
-- TABLE, migration 7) has had real RLS since migration 12, but the actual
-- Storage bucket its `storage_path` column points into was never created
-- in a migration — it would have to be created by hand in the Supabase
-- dashboard whenever the upload UI is eventually built, unversioned and
-- unreviewable, in a project whose own migration history (16-24) shows
-- exactly how easy it is to get a permissive-by-default Postgres/Supabase
-- object's privileges wrong. This closes that gap now, ahead of any UI
-- using it, using the identical org/property/tenancy-scoping helpers the
-- id_documents table itself already relies on.
--
-- Path convention objects must be uploaded under: {org_id}/{tenancy_id}/{filename}
-- — matches id_documents.storage_path's own comment ("bucket-relative
-- path in the private id-documents Storage bucket").

insert into storage.buckets (id, name, public)
values ('id-documents', 'id-documents', false)
on conflict (id) do nothing;

-- Internal helpers, same shape as property_id_for_rent_period etc.
-- (migration 9) — needed because storage.objects policies can only see
-- the path, not join through beds/rooms/properties directly.
create or replace function property_id_for_tenancy(target_tenancy_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select r.property_id
  from tenancies t
  join beds b on b.id = t.bed_id
  join rooms r on r.id = b.room_id
  where t.id = target_tenancy_id;
$$;

create or replace function tenant_owns_tenancy(target_tenancy_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from tenancies t where t.id = target_tenancy_id and t.profile_id = auth.uid()
  );
$$;

grant execute on function property_id_for_tenancy(uuid) to authenticated;
grant execute on function tenant_owns_tenancy(uuid) to authenticated;

comment on function property_id_for_tenancy(uuid) is
  'Internal RLS helper for id-documents storage policies (migration 38) — resolves a tenancy_id path segment to the property it belongs to, for is_manager_of_property checks.';

-- select: staff (org-wide Owner, scoped Manager) + the tenant themselves.
create policy "owner reads own org id documents" on storage.objects
  for select using (
    bucket_id = 'id-documents'
    and is_owner_of_org(((storage.foldername(name))[1])::uuid)
  );
create policy "manager reads scoped id documents" on storage.objects
  for select using (
    bucket_id = 'id-documents'
    and is_manager_of_property(property_id_for_tenancy(((storage.foldername(name))[2])::uuid))
  );
create policy "tenant reads own id documents" on storage.objects
  for select using (
    bucket_id = 'id-documents'
    and tenant_owns_tenancy(((storage.foldername(name))[2])::uuid)
  );

-- insert: staff uploading on a tenant's behalf, or the tenant uploading
-- their own — both scoped to the SAME tenancy/property the row-level
-- id_documents policies already enforce, so a client can never write into
-- another org's/tenant's folder even with a guessed path.
create policy "owner uploads own org id documents" on storage.objects
  for insert with check (
    bucket_id = 'id-documents'
    and is_owner_of_org(((storage.foldername(name))[1])::uuid)
  );
create policy "manager uploads scoped id documents" on storage.objects
  for insert with check (
    bucket_id = 'id-documents'
    and is_manager_of_property(property_id_for_tenancy(((storage.foldername(name))[2])::uuid))
  );
create policy "tenant uploads own id documents" on storage.objects
  for insert with check (
    bucket_id = 'id-documents'
    and tenant_owns_tenancy(((storage.foldername(name))[2])::uuid)
  );

-- No update/delete policy for anyone, deliberately — id_documents' own
-- design is a re-upload chain (superseded_by, migration 7), never an
-- in-place overwrite or removal. Default-deny (no matching policy) is the
-- correct behavior here, not an oversight.

comment on function tenant_owns_tenancy(uuid) is
  'Internal RLS helper for id-documents storage policies (migration 38) — a tenant may read/upload documents for any tenancy that is genuinely theirs (mirrors the id_documents table policy''s own no-status-restriction shape from migration 12).';
