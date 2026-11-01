-- PG Khata — migration 6/12: complaints, event-sourced on top of a cached
-- current state.
--
-- See docs/backend-domain-model.md §3/§7: the mock's delegateComplaint
-- overwrites delegated_to/delegated_at/note in place, losing who was
-- assigned before a reassignment. complaint_events is the append-only fix;
-- complaints keeps cached "current" columns (delegated_to/delegated_at/
-- note/status) so every existing read query stays a single-table lookup.

create table complaints (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references properties (id) on delete restrict,
  tenancy_id uuid references tenancies (id), -- nullable: common-area complaints aren't tied to one tenant
  category text not null check (category in ('plumbing', 'electrical', 'wifi', 'cleaning', 'other')),
  severity text not null check (severity in ('low', 'medium', 'high')),
  title text not null,
  room_label text not null, -- display string ("B-204" or "Floor 2") — matches current Complaint.room
  time_preference text not null check (time_preference in ('anytime', 'morning', 'afternoon', 'evening')),
  reported_by uuid not null references profiles (id),
  reported_at timestamptz not null default now(),
  -- Cached "current" state, kept in sync by the trigger below from
  -- complaint_events — never written directly by application code.
  status text not null default 'reported'
    check (status in ('reported', 'delegated', 'resolved', 'reopened')),
  delegated_to text, -- free-text label ("Cleaner", "Electrician", ...) — not a real account, see docs/domain-model-notes.md
  delegated_at timestamptz,
  note text,
  auto_resolve_days int not null default 3,
  org_id uuid not null, -- denormalized, see §4
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger complaints_set_updated_at
  before update on complaints
  for each row execute function set_updated_at();

create index complaints_property_id_idx on complaints (property_id);
create index complaints_tenancy_id_idx on complaints (tenancy_id) where tenancy_id is not null;
create index complaints_org_id_idx on complaints (org_id);
-- Manager Complaints' primary read pattern: open (non-resolved) complaints
-- for a property, sorted by severity — see the audit's cross-cutting notes.
create index complaints_open_idx on complaints (property_id, severity) where status <> 'resolved';

comment on table complaints is
  'status/delegated_to/delegated_at/note are a cache of the LATEST complaint_events row, not independent state — see the trigger below. effective_status (below) is what the UI actually shows, computed live, exactly matching Complaint.effectiveStatus in the current Dart code.';

create or replace function complaints_set_org_id()
returns trigger
language plpgsql
as $$
begin
  select org_id into new.org_id from properties where id = new.property_id;
  if new.org_id is null then
    raise exception 'property % does not resolve to an org', new.property_id;
  end if;
  return new;
end;
$$;

create trigger complaints_set_org_id_trigger
  before insert on complaints
  for each row execute function complaints_set_org_id();

-- Append-only timeline. Every delegate/reassign/resolve/reopen writes here
-- first; the complaints row's cached columns are then updated by trigger
-- from this table, never the other way around.
create table complaint_events (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references complaints (id) on delete cascade,
  event_type text not null check (event_type in ('reported', 'delegated', 'resolved', 'reopened')),
  actor_user_id uuid not null references profiles (id),
  assignee text, -- only set on a 'delegated' event
  note text,
  created_at timestamptz not null default now()
);

create index complaint_events_complaint_id_idx on complaint_events (complaint_id, created_at);

comment on table complaint_events is
  'Append-only complaint timeline — never updated or deleted. A "Reassign" action is just another delegated event with a new assignee, so who was assigned before is never lost. See docs/backend-domain-model.md §3.';

create or replace function complaint_events_apply()
returns trigger
language plpgsql
as $$
begin
  update complaints
  set status = new.event_type,
      delegated_to = case when new.event_type = 'delegated' then new.assignee else delegated_to end,
      delegated_at = case when new.event_type = 'delegated' then new.created_at else delegated_at end,
      note = case when new.event_type = 'delegated' then new.note else note end
  where id = new.complaint_id;
  return new;
end;
$$;

create trigger complaint_events_apply_trigger
  after insert on complaint_events
  for each row execute function complaint_events_apply();

comment on trigger complaint_events_apply_trigger on complaint_events is
  'Keeps complaints'' cached current-state columns in sync with the append-only timeline — the one and only writer of those columns.';

-- Time-derived auto-resolve, computed live — exactly like Complaint.
-- effectiveStatus in the current Dart code and Manager Complaints.dc.html's
-- own effectiveStatus() JS function. NEVER a stored/cron-flipped column, so
-- it can't drift from "now."
create or replace function complaint_effective_status(c complaints)
returns text
language sql
stable
as $$
  select case
    when c.status = 'delegated'
      and c.delegated_at is not null
      and now() - c.delegated_at >= make_interval(days => c.auto_resolve_days)
    then 'resolved'
    else c.status
  end;
$$;

comment on function complaint_effective_status(complaints) is
  'What the UI shows for a complaint''s status — mirrors Complaint.effectiveStatus in mobile/lib/features/complaints/domain/complaint.dart exactly. Usage: select *, complaint_effective_status(complaints) from complaints.';
