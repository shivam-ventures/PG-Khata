-- PG Khata — real backend, migration 1/12: extensions.
--
-- See docs/backend-domain-model.md for the full design this migration set
-- implements. Status/role fields throughout this schema use `text` +
-- `check (...)` rather than native Postgres enums — enums are painful to
-- extend later (ALTER TYPE has real restrictions inside transactions),
-- and several of these fields (tenancy status, payment status) are exactly
-- the "strict state machine that will grow" case the project's own backend
-- design review flagged as the wrong fit for a native enum.

create extension if not exists "pgcrypto";

-- Generic updated_at maintenance, reused by every mutable table below.
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function set_updated_at() is
  'Reused BEFORE UPDATE trigger: stamps updated_at = now() on every row change.';
