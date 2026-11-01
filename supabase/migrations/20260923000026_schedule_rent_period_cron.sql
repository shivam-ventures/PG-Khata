-- PG Khata — migration 26: real recurring schedule for generate_rent_periods().
--
-- generate_rent_periods() (migration 9) already refuses to run under a
-- normal user session (raises if auth.uid() is not null) — it was written
-- to be invoked only from a service-role/scheduled context. Until now
-- nothing actually scheduled it. pg_cron runs scheduled jobs as the
-- database owner with no JWT/session attached, so auth.uid() is null and
-- the function's own guard is satisfied naturally.
--
-- Schedule: 00:05 UTC on the 1st of every month — just after midnight, so
-- the new month's periods exist before anyone checks Payments that
-- morning. Migration 25 covers mid-month joiners (their first, prorated
-- period is created immediately at tenancy creation); this covers the
-- steady-state monthly rollover for everyone already tenanted.

create extension if not exists pg_cron with schema pg_catalog;

grant usage on schema cron to postgres;

select
  cron.schedule(
    'generate-rent-periods-monthly',
    '5 0 1 * *',
    $$select generate_rent_periods()$$
  )
where not exists (
  select 1 from cron.job where jobname = 'generate-rent-periods-monthly'
);
