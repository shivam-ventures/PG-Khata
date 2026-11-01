-- PG Khata — migration 7/12: identity documents (schema-only, no current
-- UI writes to this — see docs/backend-domain-model.md §10/§12.5),
-- notifications, and the audit log.

create table id_documents (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references tenancies (id) on delete cascade,
  document_type text not null check (document_type in ('id_front', 'id_back', 'photo', 'other')),
  storage_path text not null, -- bucket-relative path in the private `id-documents` Storage bucket, never a public URL
  uploaded_by uuid not null references profiles (id),
  checked_by_staff boolean not null default false,
  superseded_by uuid references id_documents (id), -- re-upload chain, see §5: a re-upload inserts a new row rather than overwriting
  org_id uuid not null,
  created_at timestamptz not null default now()
);

create index id_documents_tenancy_id_idx on id_documents (tenancy_id);
create index id_documents_org_id_idx on id_documents (org_id);

comment on table id_documents is
  'Scoped per TENANCY, not per tenant identity — a document uploaded for one org''s PG is never visible to a different org for the same person, even though the person (profiles/tenant_profiles) is shared. This is the whole point of the identity/tenancy split for privacy. Schema exists now; no current screen uploads to it (document_scan.dart is an unrelated OCR form-fill convenience). See docs/backend-domain-model.md §10, §12.5.';

create or replace function id_documents_set_org_id()
returns trigger
language plpgsql
as $$
begin
  select org_id into new.org_id from tenancies where id = new.tenancy_id;
  return new;
end;
$$;

create trigger id_documents_set_org_id_trigger
  before insert on id_documents
  for each row execute function id_documents_set_org_id();

-- Minimal, in-app only — no delivery-channel coupling (SMS/WhatsApp/push
-- are all separate infrastructure for a later phase). entity_type/
-- entity_id are a soft reference (no FK) so this table never blocks a
-- referenced row's own delete/archive policy, and outlives it if needed.
create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references profiles (id) on delete cascade,
  kind text not null, -- e.g. 'payment_recorded', 'payment_disputed', 'complaint_delegated' — open-ended on purpose
  title text not null,
  body text,
  entity_type text, -- e.g. 'payment', 'complaint' — soft reference, not a FK
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_recipient_unread_idx on notifications (recipient_user_id) where read_at is null;

comment on table notifications is
  'In-app notifications only, per docs/architecture.md''s unchanged §32 conclusion. Not written by any RPC in this migration set yet (no current screen sends any) — the shape exists so the RPCs added in migrations 9-11 have somewhere to insert into once notification UX is designed.';

-- Meaningful mutations only — never a log of reads, never secrets.
-- entity_type/entity_id are soft references for the same reason as
-- notifications: this table must outlive whatever it audited, including
-- past an archive.
create table audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references profiles (id), -- null for a system/scheduled action (e.g. generate_rent_periods)
  org_id uuid, -- null only for actions with no org context (shouldn't happen in practice, kept nullable defensively)
  action text not null, -- e.g. 'payment.recorded', 'payment.dispute_resolved', 'complaint.delegated', 'tenancy.moved_out'
  entity_type text not null,
  entity_id uuid not null,
  metadata jsonb not null default '{}', -- e.g. {"from_status": "disputed", "to_status": "paid", "note": "..."}
  created_at timestamptz not null default now()
);

create index audit_log_org_id_idx on audit_log (org_id, created_at desc);
create index audit_log_entity_idx on audit_log (entity_type, entity_id);

comment on table audit_log is
  'Meaningful financial/occupancy/complaint mutations only, written by the RPCs in migrations 9-11 — never by a raw client UPDATE. Never deleted (see docs/backend-domain-model.md §5) — outlives whatever it references.';
