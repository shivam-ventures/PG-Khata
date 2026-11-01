-- PG Khata — migration 36: RLS should not grant DELETE on
-- properties/rooms/beds at all.
--
-- Gap found during the pre-launch audit (2026-09-25): migration 12's
-- "owner all own org {properties,rooms,beds}" and "manager scoped
-- {rooms,beds} rw" policies use `for all`, which includes DELETE — but the
-- product's own documented model is archive, never hard-delete, once a
-- room/bed/property can have real history under it (see properties'
-- archived_at column and its comment in migration 3). No Flutter code
-- calls `.delete()` on any of these three tables today (confirmed via
-- audit), so this was not an exploited hole, but it's live and reachable
-- by anyone replaying an Owner's/Manager's own JWT directly against the
-- API — the FK `on delete restrict` chain still protects any row with real
-- children, but an empty, never-occupied room/bed/property could be
-- permanently removed with no trace, contradicting the archive-only design
-- and losing the audit_log's ability to say what existed. Tightened here to
-- match the documented invariant exactly: select/insert/update only.

drop policy "owner all own org properties" on properties;
create policy "owner rw own org properties" on properties for select using (
  is_owner_of_org(org_id)
);
create policy "owner insert own org properties" on properties for insert with check (
  is_owner_of_org(org_id)
);
create policy "owner update own org properties" on properties for update using (
  is_owner_of_org(org_id)
) with check (
  is_owner_of_org(org_id)
);

drop policy "owner all own org rooms" on rooms;
create policy "owner select own org rooms" on rooms for select using (
  is_owner_of_org((select org_id from properties where id = rooms.property_id))
);
create policy "owner insert own org rooms" on rooms for insert with check (
  is_owner_of_org((select org_id from properties where id = rooms.property_id))
);
create policy "owner update own org rooms" on rooms for update using (
  is_owner_of_org((select org_id from properties where id = rooms.property_id))
) with check (
  is_owner_of_org((select org_id from properties where id = rooms.property_id))
);

drop policy "manager scoped rooms rw" on rooms;
create policy "manager select scoped rooms" on rooms for select using (
  is_manager_of_property(property_id)
);
create policy "manager insert scoped rooms" on rooms for insert with check (
  is_manager_of_property(property_id)
);
create policy "manager update scoped rooms" on rooms for update using (
  is_manager_of_property(property_id)
) with check (
  is_manager_of_property(property_id)
);

drop policy "owner all own org beds" on beds;
create policy "owner select own org beds" on beds for select using (
  is_owner_of_org((select p.org_id from rooms r join properties p on p.id = r.property_id where r.id = beds.room_id))
);
create policy "owner insert own org beds" on beds for insert with check (
  is_owner_of_org((select p.org_id from rooms r join properties p on p.id = r.property_id where r.id = beds.room_id))
);
create policy "owner update own org beds" on beds for update using (
  is_owner_of_org((select p.org_id from rooms r join properties p on p.id = r.property_id where r.id = beds.room_id))
) with check (
  is_owner_of_org((select p.org_id from rooms r join properties p on p.id = r.property_id where r.id = beds.room_id))
);

drop policy "manager scoped beds rw" on beds;
create policy "manager select scoped beds" on beds for select using (
  is_manager_of_property((select property_id from rooms where id = beds.room_id))
);
create policy "manager insert scoped beds" on beds for insert with check (
  is_manager_of_property((select property_id from rooms where id = beds.room_id))
);
create policy "manager update scoped beds" on beds for update using (
  is_manager_of_property((select property_id from rooms where id = beds.room_id))
) with check (
  is_manager_of_property((select property_id from rooms where id = beds.room_id))
);

comment on table properties is
  'One PG. total_beds is a declared capacity — actual occupied/vacant counts are always computed from rooms/beds/tenancies, never stored here. Archive-only by RLS design (migration 36) — Owner/Manager policies never grant DELETE; archived_at is the only supported removal path.';
