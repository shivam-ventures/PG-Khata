-- PG Khata — migration 3/12: properties, rooms, beds.
--
-- See docs/backend-domain-model.md §1-2 (no Building/Floor entity — floor
-- stays a free-text column on rooms, matching the current Flutter Room
-- class exactly), §5 (archive, not delete), §6 (bed occupancy is derived,
-- never stored), §12.8 (room number unique per property regardless of
-- floor; bed label unique per room).

create table properties (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations (id) on delete restrict,
  name text not null,
  address text not null,
  total_beds int not null check (total_beds > 0), -- Owner-declared capacity, matches Property.totalBeds; NOT reconciled against actual room/bed rows automatically
  archived_at timestamptz, -- see §5: archive, never hard-delete once rooms/tenants/payments can exist under it
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger properties_set_updated_at
  before update on properties
  for each row execute function set_updated_at();

create index properties_org_id_idx on properties (org_id) where archived_at is null;

comment on table properties is
  'One PG. total_beds is a declared capacity (matches the current Flutter Property domain class) — actual occupied/vacant counts are always computed from rooms/beds/tenancies, never stored here. See property_metrics in migration 8.';

-- Now that properties exists, complete property_managers' forward reference.
alter table property_managers
  add constraint property_managers_property_id_fkey
    foreign key (property_id) references properties (id) on delete cascade;

create unique index property_managers_active_assignment_idx
  on property_managers (property_id, manager_user_id)
  where unassigned_at is null;

comment on index property_managers_active_assignment_idx is
  'Prevents assigning the same Manager to the same property twice while already active — reassigning after an unassign is fine (a new row).';

create table rooms (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references properties (id) on delete restrict,
  floor_label text not null, -- free text, e.g. "Ground Floor" — matches current Room.floor exactly, no separate Floor entity
  room_number text not null,
  sharing_type text not null check (sharing_type in ('single', 'double', 'triple', 'four')),
  rent_per_bed numeric(10, 2) not null check (rent_per_bed > 0),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger rooms_set_updated_at
  before update on rooms
  for each row execute function set_updated_at();

-- §12.8: a room number is unique across the whole property regardless of
-- floor — matches how Owner/Manager Rooms screens already treat room
-- number as a property-wide search key, not a floor-scoped one.
create unique index rooms_property_id_room_number_idx on rooms (property_id, room_number);
create index rooms_property_id_idx on rooms (property_id) where archived_at is null;

comment on table rooms is
  'Floor is a free-text label, not an entity — see docs/domain-model-notes.md''s own conclusion, unchanged by this backend pass. Room number is unique per property (not per floor) — see §12.8.';

create table beds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms (id) on delete restrict,
  label text not null, -- 'A' / 'B' / 'C' / 'D', per SharingType.bedCount
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

-- §12.8: a bed label is unique within its room only — freely reused across
-- rooms (every room has an "A" bed), exactly matching what's seeded today.
create unique index beds_room_id_label_idx on beds (room_id, label);
create index beds_room_id_idx on beds (room_id) where archived_at is null;

comment on table beds is
  'No status column, deliberately — see docs/backend-domain-model.md §6. Whether a bed is vacant is always derived from tenancies (bed_occupancy view, added once tenancies exists in migration 4), never stored here, so it can never drift from the ledger the way Property''s stats once did in the Flutter app.';
