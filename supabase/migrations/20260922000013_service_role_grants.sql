-- PG Khata — migration 13: grants needed by the Edge Functions
-- (add-tenant, resolve-invite) that run under the service role.
--
-- create_tenancy_for_profile is otherwise internal-only (called from
-- other security-definer functions) — the add-tenant Edge Function is the
-- one legitimate case of a *different* execution context (Deno, using the
-- service role key) needing to call it directly, because staff-adding a
-- person who has never opened the app requires the Admin API (creating
-- their auth.users row), which only runs in that Edge Function, not in a
-- plain Postgres RPC. See docs/backend-domain-model.md §11.

grant execute on function create_tenancy_for_profile(uuid, uuid, numeric, smallint, numeric, date, text, uuid) to service_role;
