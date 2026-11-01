-- PG Khata — migration 14: fix bed occupancy to include notice_period.
--
-- Bug found while verifying seed data: bed_occupancy and the anti-double-
-- booking unique index only treated status = 'active' as "occupying a
-- bed." A tenant serving notice is still physically in the bed — only
-- moved_out actually frees it. As written, this both undercounted
-- occupancy (a notice_period tenant's bed showed as vacant in
-- property_metrics) AND would have allowed a second tenancy to be created
-- on a bed whose occupant is merely serving notice, defeating the
-- one-tenancy-per-bed invariant docs/backend-domain-model.md §3 exists to
-- guarantee.

drop index tenancies_one_active_per_bed_idx;
create unique index tenancies_one_active_per_bed_idx
  on tenancies (bed_id)
  where status in ('active', 'notice_period');

comment on index tenancies_one_active_per_bed_idx is
  'At most one CURRENT tenancy (active or notice_period) per bed — only moved_out actually frees it. Fixed 2026-09-22 after seed-data verification caught the original active-only version undercounting occupancy.';

create or replace view bed_occupancy as
select
  b.id as bed_id,
  b.room_id,
  t.id as active_tenancy_id,
  t.profile_id as active_tenant_profile_id,
  (t.id is not null) as is_occupied
from beds b
left join tenancies t on t.bed_id = b.id and t.status in ('active', 'notice_period');
