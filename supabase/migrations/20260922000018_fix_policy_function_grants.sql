-- PG Khata — migration 18: correct the migration 17/16 overcorrection.
--
-- Migration 17 revoked EXECUTE from `anon, authenticated` on every
-- internal helper, including ones referenced directly inside RLS policy
-- USING expressions (is_owner_of_org, is_manager_of_property, etc.) and
-- migration 16 did the same for its three new helpers. That broke RLS
-- entirely for authenticated users ("permission denied for function
-- is_owner_of_org") — caught immediately by re-running the same manager
-- scoping test that had just passed.
--
-- The distinction that matters, learned from this exact failure:
--   - A function called FROM WITHIN another SECURITY DEFINER function's
--     BODY (e.g. assign_tenant_to_bed calling create_tenancy_for_profile)
--     is checked against that function's OWNER role (postgres), because
--     SECURITY DEFINER elevates everything that happens once execution is
--     inside it — the original caller's grants are irrelevant there.
--   - A function referenced INSIDE AN RLS POLICY EXPRESSION is evaluated
--     as part of the query plan for the QUERYING ROLE itself (RLS is
--     conceptually an appended WHERE clause on the original statement,
--     not a nested function call) — so the querying role (`authenticated`)
--     DOES need EXECUTE on it, regardless of the function being SECURITY
--     DEFINER.
--
-- create_tenancy_for_profile and generate_rent_periods are correctly
-- still revoked from anon/authenticated — neither is ever referenced in
-- an RLS policy, only called from within other functions' bodies or by
-- service_role directly.

grant execute on function auth_profile() to authenticated;
grant execute on function is_owner_of_org(uuid) to authenticated;
grant execute on function is_manager_of_property(uuid) to authenticated;
grant execute on function is_staff_for_property(uuid) to authenticated;
grant execute on function property_id_for_rent_period(uuid) to authenticated;
grant execute on function property_id_for_payment(uuid) to authenticated;
grant execute on function property_id_for_bed(uuid) to authenticated;
grant execute on function tenant_owns_rent_period(uuid) to authenticated;
grant execute on function tenant_owns_payment(uuid) to authenticated;
grant execute on function tenant_owns_complaint(uuid) to authenticated;
grant execute on function tenant_has_current_bed(uuid) to authenticated;
grant execute on function tenant_has_current_room(uuid) to authenticated;
grant execute on function complaint_effective_status(complaints) to authenticated;

comment on function is_owner_of_org(uuid) is
  'Referenced inside RLS policies across most tables — MUST stay granted to authenticated (see this migration''s comment for why that differs from create_tenancy_for_profile, which must NOT be). Read-only (returns a boolean), so granting it does not expose any authorization bypass, only a boolean/uuid probe at worst.';
