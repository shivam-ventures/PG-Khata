-- PG Khata — migration 30: PG announcements.
--
-- The tenant-facing display slot for this has existed since Phase 0
-- (`TenantHomeData.announcement`) but nothing has ever written to it — no
-- authoring screen, no backing table (docs/design-readme-reconciliation.md
-- §3's "PG announcements" gap). This closes it: a per-property broadcast
-- an Owner/Manager posts, shown to that property's current tenants, with
-- an in-app notification the moment it's posted so nobody has to be on
-- Home already to see it.

create table announcements (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references properties (id),
  title text not null,
  body text not null,
  created_by uuid not null references profiles (id),
  created_at timestamptz not null default now(),
  -- Optional — an announcement with no expiry stays "current" until a
  -- newer one for the same property is posted (the read side only ever
  -- shows the single latest, non-expired one; older rows are just history).
  expires_at timestamptz
);

create index announcements_property_created_idx
  on announcements (property_id, created_at desc);

alter table announcements enable row level security;

create policy "staff manages own property announcements" on announcements
  for all using (is_staff_for_property(property_id))
  with check (is_staff_for_property(property_id));

create policy "tenant reads own property announcements" on announcements
  for select using (tenant_has_current_property(property_id));

comment on table announcements is
  'A per-property broadcast from Owner/Manager to that property''s current tenants — see create_announcement(). Deleting one (staff-only, via the "manages" policy) just ends it early; older rows are kept as history, never auto-purged.';

create or replace function create_announcement(
  p_property_id uuid,
  p_title text,
  p_body text,
  p_expires_at timestamptz default null
)
returns announcements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_announcement announcements;
  v_tenant record;
begin
  if not is_staff_for_property(p_property_id) then
    raise exception 'not authorized to post an announcement for this property';
  end if;
  if p_body is null or length(trim(p_body)) = 0 then
    raise exception 'announcement body is required';
  end if;

  insert into announcements (property_id, title, body, created_by, expires_at)
  values (
    p_property_id, coalesce(nullif(trim(p_title), ''), 'Announcement'),
    trim(p_body), auth.uid(), p_expires_at
  )
  returning * into v_announcement;

  for v_tenant in
    select distinct t.profile_id
    from tenancies t
    join beds b on b.id = t.bed_id
    join rooms r on r.id = b.room_id
    where r.property_id = p_property_id and t.status in ('active', 'notice_period')
  loop
    perform notify_user(
      v_tenant.profile_id, 'announcement', v_announcement.title, v_announcement.body,
      'announcement', v_announcement.id
    );
  end loop;

  return v_announcement;
end;
$$;
