-- PG Khata — migration 19: CRITICAL — views were leaking cross-org data.
--
-- Found immediately after fixing migration 17/18's grant issue, by
-- re-running the exact same manager-scoping test against property_metrics:
-- it returned ALL THREE properties, including Koramangala — a PG Ramesh
-- is NOT assigned to. Root cause: Postgres views default to
-- `security_invoker = false`, meaning a view executes with the VIEW
-- OWNER's privileges against its underlying tables (bypassing RLS
-- entirely) unless explicitly told otherwise. Every view in this schema
-- (property_metrics, bed_occupancy, rent_period_status) had this problem
-- — combined with the same default-privilege SELECT grant to anon/
-- authenticated found in migration 17, this meant ANY authenticated user,
-- or literally anyone holding just the public anon key, could read every
-- organization's full occupancy and financial rollups.
--
-- This is the same lesson as migration 17/18 from a different angle:
-- Postgres/Supabase's permissive defaults (function grants, view security
-- mode) both favor "just works" over "secure by default," and BOTH must
-- be explicitly locked down — a `using (true)`-free RLS policy set is not
-- sufficient by itself if the objects sitting in front of those tables
-- don't also respect it.

alter view property_metrics set (security_invoker = true);
alter view bed_occupancy set (security_invoker = true);
alter view rent_period_status set (security_invoker = true);

revoke select on property_metrics from anon;
revoke select on bed_occupancy from anon;
revoke select on rent_period_status from anon;

comment on view property_metrics is
  'security_invoker = true — MUST stay set. Without it this view bypasses RLS on properties/rooms/beds/tenancies/payments/complaints entirely, as discovered and fixed 2026-09-22 (a Manager could read every organization''s financials). See docs/backend-domain-model.md §6.';
