-- PG Khata — migration 12/12: Row Level Security + function execute grants.
--
-- This is the actual authorization boundary — see docs/backend-domain-model.md
-- §9. No table uses `using (true)`. Every table with a state machine
-- (tenancies, rent_periods, payments, payment_allocations, complaints,
-- complaint_events) gets SELECT-only policies for client roles — every
-- write to those tables happens through the security-definer functions in
-- migrations 9-11, which run as the function owner and so bypass RLS
-- themselves after doing their own explicit auth check (§18: authorization
-- and business validation both live in the function).
--
-- Tables with simple CRUD and no state machine (properties, rooms, beds,
-- property_managers, organizations, profiles) get direct RLS-governed
-- INSERT/UPDATE, matching §11's "don't over-RPC-ify simple CRUD."

alter table profiles enable row level security;
alter table tenant_profiles enable row level security;
alter table organizations enable row level security;
alter table property_managers enable row level security;
alter table properties enable row level security;
alter table rooms enable row level security;
alter table beds enable row level security;
alter table tenancies enable row level security;
alter table rent_periods enable row level security;
alter table payments enable row level security;
alter table payment_allocations enable row level security;
alter table complaints enable row level security;
alter table complaint_events enable row level security;
alter table id_documents enable row level security;
alter table tenant_invite_links enable row level security;
alter table notifications enable row level security;
alter table audit_log enable row level security;

-- ---------------------------------------------------------------------
-- profiles / tenant_profiles / organizations / property_managers
-- ---------------------------------------------------------------------

create policy "read own profile" on profiles for select using (id = auth.uid());
create policy "insert own profile" on profiles for insert with check (id = auth.uid());
create policy "update own profile" on profiles for update using (id = auth.uid());

create policy "owner reads org profiles" on profiles for select using (
  exists (
    select 1 from property_managers pm join properties p on p.id = pm.property_id
    where pm.manager_user_id = profiles.id and is_owner_of_org(p.org_id)
  )
  or exists (
    select 1 from tenancies t
    join beds b on b.id = t.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where t.profile_id = profiles.id and is_owner_of_org(p.org_id)
  )
);

create policy "manager reads scoped tenant profiles" on profiles for select using (
  exists (
    select 1 from tenancies t join beds b on b.id = t.bed_id join rooms r on r.id = b.room_id
    where t.profile_id = profiles.id and is_manager_of_property(r.property_id)
  )
);

create policy "tenant reads own tenant profile" on tenant_profiles for select using (id = auth.uid());
create policy "tenant writes own tenant profile" on tenant_profiles for insert with check (id = auth.uid());
create policy "tenant updates own tenant profile" on tenant_profiles for update using (id = auth.uid());
create policy "owner reads org tenant profiles" on tenant_profiles for select using (
  exists (
    select 1 from tenancies t
    join beds b on b.id = t.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where t.profile_id = tenant_profiles.id and is_owner_of_org(p.org_id)
  )
);
create policy "manager reads scoped tenant profiles" on tenant_profiles for select using (
  exists (
    select 1 from tenancies t join beds b on b.id = t.bed_id join rooms r on r.id = b.room_id
    where t.profile_id = tenant_profiles.id and is_manager_of_property(r.property_id)
  )
);

create policy "owner reads own org" on organizations for select using (owner_user_id = auth.uid());
create policy "owner creates own org" on organizations for insert with check (owner_user_id = auth.uid());
create policy "owner updates own org" on organizations for update using (owner_user_id = auth.uid());

create policy "owner manages own org assignments" on property_managers for all using (
  is_owner_of_org((select org_id from properties where id = property_managers.property_id))
) with check (
  is_owner_of_org((select org_id from properties where id = property_managers.property_id))
);
create policy "manager reads own assignment" on property_managers for select using (manager_user_id = auth.uid());

-- ---------------------------------------------------------------------
-- properties / rooms / beds — simple CRUD under RLS, no RPC needed
-- ---------------------------------------------------------------------

create policy "owner all own org properties" on properties for all using (
  is_owner_of_org(org_id)
) with check (
  is_owner_of_org(org_id)
);
create policy "manager reads assigned properties" on properties for select using (
  is_manager_of_property(id)
);

create policy "owner all own org rooms" on rooms for all using (
  is_owner_of_org((select org_id from properties where id = rooms.property_id))
) with check (
  is_owner_of_org((select org_id from properties where id = rooms.property_id))
);
create policy "manager scoped rooms rw" on rooms for all using (
  is_manager_of_property(property_id)
) with check (
  is_manager_of_property(property_id)
);
create policy "tenant reads own room" on rooms for select using (
  exists (
    select 1 from tenancies t join beds b on b.id = t.bed_id
    where b.room_id = rooms.id and t.profile_id = auth.uid() and t.status = 'active'
  )
);

create policy "owner all own org beds" on beds for all using (
  is_owner_of_org((select p.org_id from rooms r join properties p on p.id = r.property_id where r.id = beds.room_id))
) with check (
  is_owner_of_org((select p.org_id from rooms r join properties p on p.id = r.property_id where r.id = beds.room_id))
);
create policy "manager scoped beds rw" on beds for all using (
  is_manager_of_property((select property_id from rooms where id = beds.room_id))
) with check (
  is_manager_of_property((select property_id from rooms where id = beds.room_id))
);
create policy "tenant reads own bed" on beds for select using (
  exists (select 1 from tenancies t where t.bed_id = beds.id and t.profile_id = auth.uid() and t.status = 'active')
);

-- ---------------------------------------------------------------------
-- tenancies / rent_periods / payments / payment_allocations —
-- SELECT only; every write is one of migrations 9/11's RPCs.
-- ---------------------------------------------------------------------

create policy "owner reads own org tenancies" on tenancies for select using (is_owner_of_org(org_id));
create policy "manager reads scoped tenancies" on tenancies for select using (
  is_manager_of_property((select r.property_id from beds b join rooms r on r.id = b.room_id where b.id = tenancies.bed_id))
);
create policy "tenant reads own tenancies" on tenancies for select using (profile_id = auth.uid());

create policy "owner reads own org rent periods" on rent_periods for select using (is_owner_of_org(org_id));
create policy "manager reads scoped rent periods" on rent_periods for select using (
  is_manager_of_property(property_id_for_rent_period(id))
);
create policy "tenant reads own rent periods" on rent_periods for select using (
  exists (select 1 from tenancies t where t.id = rent_periods.tenancy_id and t.profile_id = auth.uid())
);

create policy "owner reads own org payments" on payments for select using (is_owner_of_org(org_id));
create policy "manager reads scoped payments" on payments for select using (
  is_manager_of_property(property_id_for_payment(id))
);
create policy "tenant reads own payments" on payments for select using (tenant_owns_payment(id));

create policy "owner reads own org allocations" on payment_allocations for select using (
  is_owner_of_org((select org_id from payments where id = payment_allocations.payment_id))
);
create policy "manager reads scoped allocations" on payment_allocations for select using (
  is_manager_of_property(property_id_for_payment(payment_allocations.payment_id))
);
create policy "tenant reads own allocations" on payment_allocations for select using (
  tenant_owns_payment(payment_allocations.payment_id)
);

-- ---------------------------------------------------------------------
-- complaints / complaint_events — SELECT only; writes via migration 10.
-- ---------------------------------------------------------------------

create policy "owner reads own org complaints" on complaints for select using (is_owner_of_org(org_id));
create policy "manager reads scoped complaints" on complaints for select using (is_manager_of_property(property_id));
create policy "tenant reads own complaints" on complaints for select using (tenant_owns_complaint(id));

create policy "owner reads own org complaint events" on complaint_events for select using (
  is_owner_of_org((select org_id from complaints where id = complaint_events.complaint_id))
);
create policy "manager reads scoped complaint events" on complaint_events for select using (
  is_manager_of_property((select property_id from complaints where id = complaint_events.complaint_id))
);
create policy "tenant reads own complaint events" on complaint_events for select using (
  tenant_owns_complaint(complaint_events.complaint_id)
);

-- ---------------------------------------------------------------------
-- id_documents — tenant can also insert their own (this is a plain
-- upload, not a state machine, so no RPC needed for it specifically).
-- ---------------------------------------------------------------------

create policy "owner reads own org documents" on id_documents for select using (is_owner_of_org(org_id));
create policy "manager reads scoped documents" on id_documents for select using (
  is_manager_of_property((
    select r.property_id from tenancies t join beds b on b.id = t.bed_id join rooms r on r.id = b.room_id
    where t.id = id_documents.tenancy_id
  ))
);
create policy "tenant reads own documents" on id_documents for select using (
  exists (select 1 from tenancies t where t.id = id_documents.tenancy_id and t.profile_id = auth.uid())
);
create policy "tenant uploads own documents" on id_documents for insert with check (
  uploaded_by = auth.uid()
  and exists (select 1 from tenancies t where t.id = id_documents.tenancy_id and t.profile_id = auth.uid())
);

-- ---------------------------------------------------------------------
-- tenant_invite_links — staff-only. Deliberately NO tenant/anon policy:
-- an unauthenticated invitee resolves invite details via the
-- resolve-invite Edge Function (service role), same reasoning as the
-- pre-pivot schema — see docs/backend-domain-model.md §9, §12.4.
-- ---------------------------------------------------------------------

create policy "owner reads own org invite links" on tenant_invite_links for select using (
  is_owner_of_org((
    select p.org_id from beds b join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where b.id = tenant_invite_links.bed_id
  ))
);
create policy "manager reads scoped invite links" on tenant_invite_links for select using (
  is_manager_of_property((select r.property_id from beds b join rooms r on r.id = b.room_id where b.id = tenant_invite_links.bed_id))
);

-- ---------------------------------------------------------------------
-- notifications / audit_log
-- ---------------------------------------------------------------------

create policy "read own notifications" on notifications for select using (recipient_user_id = auth.uid());
create policy "mark own notifications read" on notifications for update
  using (recipient_user_id = auth.uid()) with check (recipient_user_id = auth.uid());

create policy "owner reads own org audit log" on audit_log for select using (is_owner_of_org(org_id));
create policy "manager reads assigned property audit log" on audit_log for select using (
  org_id in (
    select p.org_id from properties p join property_managers pm on pm.property_id = p.id
    where pm.manager_user_id = auth.uid() and pm.unassigned_at is null
  )
);

-- ---------------------------------------------------------------------
-- Function execute grants — deny by default, then explicitly allow.
-- Postgres grants EXECUTE on new functions to PUBLIC unless revoked;
-- `authenticated`/`anon` inherit from PUBLIC in Supabase, so every
-- function created in migrations 1-11 is currently callable by anyone
-- unless revoked here. Internal helpers/triggers never need a grant —
-- triggers run as the table owner regardless, and helpers are only ever
-- called FROM another security-definer function (which already runs with
-- elevated privilege), never directly by a client.
-- ---------------------------------------------------------------------

revoke execute on all functions in schema public from public;

-- Client-facing RPCs — authenticated users only (every one of them reads
-- auth.uid() and would be meaningless for anon anyway).
grant execute on function record_payment(uuid, text, numeric, text) to authenticated;
grant execute on function record_self_payment(uuid, text, numeric, text) to authenticated;
grant execute on function confirm_payment(uuid) to authenticated;
grant execute on function dispute_payment(uuid) to authenticated;
grant execute on function void_payment(uuid) to authenticated;
grant execute on function resolve_dispute(uuid, text, text) to authenticated;

grant execute on function report_complaint(uuid, uuid, text, text, text, text, text, text) to authenticated;
grant execute on function delegate_complaint(uuid, text, text) to authenticated;
grant execute on function resolve_complaint(uuid) to authenticated;
grant execute on function reopen_complaint(uuid, text) to authenticated;

grant execute on function assign_tenant_to_bed(uuid, uuid, numeric, smallint, numeric, date) to authenticated;
grant execute on function complete_invite_join(text, text) to authenticated;
grant execute on function move_out_tenant(uuid) to authenticated;
grant execute on function transfer_tenancy(uuid, uuid, numeric) to authenticated;
grant execute on function create_invite_link(uuid) to authenticated;

-- Scheduled/service-role only (also enforced inside the function body).
grant execute on function generate_rent_periods() to service_role;

comment on function record_payment(uuid, text, numeric, text) is
  'Client-facing RPC. Every other function in this schema not explicitly granted above is internal-only (helpers, triggers) — see the blanket revoke at the top of this section.';
