-- PG Khata — migration 15: same status-filtering bug as migration 14,
-- found in property_metrics' latest_period CTE — a notice_period tenant
-- still owes rent and should still count toward rent_collected/
-- rent_expected, not disappear from the portfolio totals entirely.

create or replace view property_metrics as
with beds_agg as (
  select
    r.property_id,
    count(b.id) as total_beds,
    count(b.id) filter (where bo.is_occupied) as occupied_beds
  from rooms r
  join beds b on b.room_id = r.id
  left join bed_occupancy bo on bo.bed_id = b.id
  where r.archived_at is null and b.archived_at is null
  group by r.property_id
),
latest_period as (
  select distinct on (t.id)
    t.id as tenancy_id,
    rp.id as rent_period_id,
    r.property_id
  from tenancies t
  join rent_periods rp on rp.tenancy_id = t.id
  join beds b on b.id = t.bed_id
  join rooms r on r.id = b.room_id
  where t.status in ('active', 'notice_period')
  order by t.id, rp.period_month desc
),
payments_agg as (
  select
    lp.property_id,
    sum(rps.amount_due) as rent_expected,
    sum(rps.paid_amount) filter (where rps.status = 'paid') as rent_collected
  from latest_period lp
  join rent_period_status rps on rps.rent_period_id = lp.rent_period_id
  group by lp.property_id
),
complaints_agg as (
  select property_id, count(*) as open_complaints
  from complaints c
  where complaint_effective_status(c) <> 'resolved'
  group by property_id
)
select
  p.id as property_id,
  p.org_id,
  coalesce(ba.total_beds, 0) as total_beds,
  coalesce(ba.occupied_beds, 0) as occupied_beds,
  coalesce(pa.rent_collected, 0) as rent_collected,
  coalesce(pa.rent_expected, 0) as rent_expected,
  coalesce(ca.open_complaints, 0) as open_complaints
from properties p
left join beds_agg ba on ba.property_id = p.id
left join payments_agg pa on pa.property_id = p.id
left join complaints_agg ca on ca.property_id = p.id
where p.archived_at is null;
