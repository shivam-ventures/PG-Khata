-- PG Khata — migration 35: keep billing a tenant through their notice period.
--
-- Gap found during the pre-launch audit (2026-09-25): generate_rent_periods
-- only ever considered status = 'active' tenancies. A tenant who gives
-- notice (status -> notice_period, migration 31) before the end of a month
-- still physically occupies the bed — the occupancy model and the
-- anti-double-booking index have treated notice_period as "current" since
-- migration 14 — but this function stopped generating new rent_periods for
-- them the moment they gave notice, silently under-billing the partial
-- month they remain.

create or replace function generate_rent_periods()
returns setof rent_periods
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period_month date := date_trunc('month', current_date)::date;
begin
  if auth.uid() is not null then
    raise exception 'generate_rent_periods is scheduled/service-role only';
  end if;

  return query
  insert into rent_periods (tenancy_id, period_month, due_date, amount_due)
  select
    t.id,
    v_period_month,
    (v_period_month + (t.rent_due_day - 1) * interval '1 day')::date,
    t.rent_amount
  from tenancies t
  where t.status in ('active', 'notice_period')
  on conflict (tenancy_id, period_month) do nothing
  returning *;
end;
$$;

comment on function generate_rent_periods() is
  'Run monthly by a scheduler (pg_cron or an external cron hitting this via the service role) — creates this month''s rent_periods for every tenancy still occupying its bed (active or notice_period — see migration 14''s occupancy model) that doesn''t already have one. Never called by the Flutter app directly. Fixed in migration 35 to include notice_period (was active-only, under-billing a tenant''s final partial month).';
