-- PG Khata — migration 17: close a real privilege-escalation hole.
--
-- CRITICAL FINDING while security-testing (docs/backend-domain-model.md
-- §9/§34 explicitly call for this, not just positive-path checks):
-- `revoke execute on all functions in schema public from public` in
-- migration 12 did NOT do what it looks like it does. Supabase projects
-- are provisioned with a default-privilege rule that grants EXECUTE
-- directly to the `anon`/`authenticated`/`service_role` roles at function
-- CREATION time — a direct grant, not inherited through the `PUBLIC`
-- pseudo-role — so revoking from `PUBLIC` afterward left every one of
-- those direct grants untouched. Verified via has_function_privilege():
-- every function created in migrations 1-15 was callable by `anon` and
-- `authenticated`, including internal helpers never meant to be called
-- directly.
--
-- The serious consequence: `create_tenancy_for_profile` has NO
-- authorization check inside it by design (it trusts its callers —
-- assign_tenant_to_bed, complete_invite_join, transfer_tenancy — to have
-- already verified the caller is allowed). With it directly callable,
-- literally anyone holding the public anon key could call
-- `create_tenancy_for_profile` with an arbitrary profile_id/bed_id and
-- create a fraudulent tenancy on any bed, for any person, fully bypassing
-- every authorization check in this schema. Same class of gap on
-- `generate_rent_periods` (its own internal auth.uid()-is-null check does
-- not block an anon caller, since anon also has no JWT-derived uid).
--
-- Fix: revoke EXECUTE from `anon, authenticated` BY NAME (not PUBLIC) on
-- every internal function, service-role-only function, and trigger
-- function. Client-facing RPCs keep their `authenticated` grant.

revoke execute on function auth_profile() from anon, authenticated;
revoke execute on function complaint_effective_status(complaints) from anon, authenticated;
revoke execute on function is_owner_of_org(uuid) from anon, authenticated;
revoke execute on function is_manager_of_property(uuid) from anon, authenticated;
revoke execute on function is_staff_for_property(uuid) from anon, authenticated;
revoke execute on function property_id_for_rent_period(uuid) from anon, authenticated;
revoke execute on function property_id_for_payment(uuid) from anon, authenticated;
revoke execute on function tenant_owns_rent_period(uuid) from anon, authenticated;
revoke execute on function tenant_owns_payment(uuid) from anon, authenticated;
revoke execute on function tenant_owns_complaint(uuid) from anon, authenticated;

-- Trigger functions — Postgres invokes these internally as part of the
-- triggering DML statement, which does not go through an EXECUTE privilege
-- check the way a direct function call does, so revoking here does not
-- break the triggers themselves; it only stops someone from invoking one
-- directly via RPC (which would error out anyway, since NEW/OLD don't
-- exist outside real trigger context — this is defense in depth, not a
-- functional fix).
revoke execute on function set_updated_at() from anon, authenticated;
revoke execute on function tenancies_set_org_id() from anon, authenticated;
revoke execute on function rent_periods_set_org_id() from anon, authenticated;
revoke execute on function payments_set_org_id() from anon, authenticated;
revoke execute on function complaints_set_org_id() from anon, authenticated;
revoke execute on function complaint_events_apply() from anon, authenticated;
revoke execute on function id_documents_set_org_id() from anon, authenticated;

-- The two functions with a real vulnerability, above — service_role only.
revoke execute on function create_tenancy_for_profile(uuid, uuid, numeric, smallint, numeric, date, text, uuid) from anon, authenticated;
revoke execute on function generate_rent_periods() from anon, authenticated;

comment on function create_tenancy_for_profile(uuid, uuid, numeric, smallint, numeric, date, text, uuid) is
  'INTERNAL — no authorization check inside by design; trusts its callers (assign_tenant_to_bed, complete_invite_join, transfer_tenancy, and the add-tenant Edge Function via service_role) to have already verified the caller. Must NEVER be granted to anon/authenticated directly — see this migration''s comment for what happened when it briefly was.';
