-- PG Khata — migration 20: revoke anon's default table-level grants.
--
-- Same root cause as migrations 17-19: Supabase's project-level default
-- privileges grant SELECT/INSERT/UPDATE/DELETE directly to `anon` (and
-- `authenticated`) on every new table. Testing confirmed RLS's
-- default-deny-when-no-policy-matches correctly blocks anon in practice
-- (a raw insert attempt into tenancies, and into payments as an
-- authenticated tenant, were both denied) — so this is not a currently
-- exploitable hole the way migrations 17/19 were. But there is no
-- legitimate anon-facing feature in this product today (no public
-- marketplace listings exist yet — see docs/backend-domain-model.md
-- §12.2/§14, deliberately deferred), and leaving anon with blanket table
-- privileges means every future policy change is one accidental `using
-- (true)` or one forgotten auth.uid() null-check away from becoming a real
-- hole, with a confusing internal-function-name error message in the
-- meantime rather than a clean denial. Defense in depth: revoke now.
--
-- `authenticated`'s table grants are intentionally left as-is — RLS is
-- what actually scopes authenticated access (verified extensively this
-- session), and revoking those too would require re-deriving exactly
-- which grants each policy needs, which is more risk for no additional
-- protection given RLS already does the real work correctly.

revoke all on all tables in schema public from anon;

-- Re-confirm no anon grants leak back in on future tables created by the
-- `postgres` role (the role every migration in this project runs as).
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on functions from anon;
