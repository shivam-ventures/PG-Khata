-- PG Khata — Phase 0 schema
--
-- Run this in your Supabase project's SQL editor (or via the Supabase CLI)
-- after creating the project. It creates every Phase 0-3 table up front
-- (Phase 0 code only reads/writes `organizations` and `profiles`) so later
-- phases don't need migrations for the core shape — just new columns/tables
-- as features need them.
--
-- Note on identity verification: there is deliberately NO Aadhaar number
-- field and no UIDAI e-KYC integration anywhere in this schema. Per the
-- product decision in docs/DECISIONS.md, Phase 0-2 store a plain ID-proof
-- photo (id_documents) with a manual "checked by staff" flag — nothing is
-- verified against UIDAI. Revisit only if a licensed Sub-KUA vendor is
-- deliberately adopted later (see the original strategic review).
--
-- Note on identity vs. tenancy (2026-09-15): a person's identity
-- (profiles/tenant_profiles) is separate from a specific stay
-- (tenancies). This matters because PG Khata's tenant app shows
-- properties across every owner on the platform, not just one owner's —
-- so the same tenant may have tenancies with different organizations
-- over their lifetime, and identity has to survive a move between them.
-- See "Cross-owner discovery + identity/tenancy split" in docs/DECISIONS.md.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Core tables
-- ---------------------------------------------------------------------

create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_user_id uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  -- Fixed home org for Owner/Manager/Super Admin. NOT meaningful for a
  -- Tenant — a tenant isn't permanently "of" one org, since they can move
  -- between different owners' properties over time (see tenancies below).
  -- A tenant's current org is always derived from their active tenancy.
  org_id uuid references organizations (id),
  role text not null check (role in ('owner', 'manager', 'tenant', 'super_admin')),
  full_name text not null default '',
  phone text not null,
  property_scope uuid[] not null default '{}', -- properties this Manager can access; empty = all (Owner/Admin)
  created_at timestamptz not null default now()
);

-- Tenant-specific identity fields that persist across every tenancy this
-- person ever has, regardless of which owner/property — one row per
-- tenant profile, created the first time they fill in emergency-contact
-- details (staff-initiated or self-initiated, either path).
create table if not exists tenant_profiles (
  id uuid primary key references profiles (id) on delete cascade,
  emergency_contact_name text,
  emergency_contact_phone text,
  created_at timestamptz not null default now()
);

create table if not exists properties (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations (id) on delete cascade,
  name text not null,
  address text,
  slug text unique, -- for a shareable "join this PG directly" link, e.g. /join/rohans-andheri-pg
  amenities text[] not null default '{}', -- simple tags for the public listing: wifi, food, laundry, ac, ...
  cover_photo_url text, -- Supabase Storage path, public bucket — listing photos are Phase 2+ UI, this column just holds the shape
  created_at timestamptz not null default now()
);

create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references properties (id) on delete cascade,
  room_no text not null,
  created_at timestamptz not null default now()
);

create table if not exists beds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms (id) on delete cascade,
  bed_no text not null,
  status text not null default 'vacant' check (status in ('vacant', 'occupied', 'hold')),
  -- Advertised rent/deposit shown to a prospective tenant browsing the
  -- public listing — separate from tenancies.rent_amount, which is
  -- whatever was actually agreed for a specific tenant (may differ).
  listed_rent numeric(10, 2),
  listed_deposit numeric(10, 2),
  created_at timestamptz not null default now()
);

-- One row per stay: a specific person, at a specific bed, for a specific
-- owner/property. Replaces what used to be a single combined "tenants"
-- table — identity now lives on profiles/tenant_profiles instead, so a
-- transfer or a move to a different owner's PG doesn't require
-- re-entering a person's name, emergency contact, or re-verifying them.
create table if not exists tenancies (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id), -- the tenant this stay belongs to
  bed_id uuid not null references beds (id),
  -- Lifecycle — see "New tenant onboarding" and "Cross-owner discovery"
  -- in docs/DECISIONS.md.
  -- pending_approval: tenant self-requested this bed; Owner/Manager hasn't
  --   accepted yet (staff-initiated tenancies skip this — staff already
  --   decided in person, so they start at pending_profile directly).
  -- pending_profile: accepted (by staff, or by approving a request), but
  --   the tenant hasn't finished emergency contact / ID photo / house
  --   rules yet.
  -- active: tenant completed everything; normal day-to-day state.
  -- notice_period / moved_out: later lifecycle stages (Phase 3+ move-out).
  -- declined: a self-requested tenancy Owner/Manager rejected — kept for
  --   record rather than deleted, so a lead isn't silently lost.
  status text not null default 'pending_profile'
    check (status in ('pending_approval', 'pending_profile', 'active', 'notice_period', 'moved_out', 'declined')),
  source text not null default 'staff_created' check (source in ('staff_created', 'tenant_requested')),
  move_in_date date, -- actual/confirmed move-in date; null until known (book-ahead path)
  expected_move_in_date date, -- set on the book-ahead path, or on a tenant's own request
  move_out_date date,
  rent_amount numeric(10, 2) not null default 0, -- the actually-agreed rent for this tenancy
  rent_due_day smallint not null default 5 check (rent_due_day between 1 and 28),
  security_deposit_amount numeric(10, 2) not null default 0,
  security_deposit_collected_at timestamptz,
  agreement_accepted_at timestamptz, -- this property's house rules — every tenancy needs its own
  created_by uuid references auth.users (id), -- Manager/Owner who added this record; null if tenant self-requested
  created_at timestamptz not null default now()
);

-- One row per magic link sent to a tenant to complete their own profile
-- (emergency contact, ID photo, house-rules acknowledgment) without an
-- Owner/Manager filling it in on their behalf. Used for the staff-
-- initiated path only — a tenant who finds the app themselves is already
-- authenticated by the time they pick a bed, so no token/link is needed
-- there. The link's token is looked up by a server route using the
-- service-role key — the tenant isn't authenticated yet when they tap it,
-- so normal RLS (below) intentionally does not grant them access here.
create table if not exists tenant_invite_links (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references tenancies (id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

-- Plain ID-proof storage — NOT Aadhaar e-KYC. See note at the top of this
-- file. Deliberately scoped to a tenancy, not the shared tenant identity:
-- a document uploaded for one owner's PG is never visible to a different
-- owner just because it's the same person — each org only ever sees what
-- was uploaded within its own relationship with that tenant. A same-org
-- transfer to a new bed can reuse it as an app-layer convenience without
-- weakening this default.
create table if not exists id_documents (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references tenancies (id) on delete cascade,
  document_type text not null check (document_type in ('id_front', 'id_back', 'photo', 'other')),
  file_url text not null, -- Supabase Storage path, private bucket
  uploaded_by uuid not null references auth.users (id),
  checked_by_staff boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references tenancies (id),
  amount numeric(10, 2) not null,
  mode text not null check (mode in ('cash', 'upi', 'card')),
  status text not null default 'paid' check (status in ('paid', 'due', 'overdue', 'partial')),
  recorded_by uuid not null references auth.users (id),
  gateway_ref text, -- null for cash — no money ever moves through the app itself, see the strategic review
  period_month date not null, -- first-of-month the payment covers, e.g. 2026-09-01
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists complaints (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references tenancies (id),
  property_id uuid not null references properties (id),
  category text not null,
  description text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved')),
  assigned_to uuid references auth.users (id),
  created_at timestamptz not null default now()
);

-- One row per in-progress (or finished) inbound WhatsApp conversation —
-- the state machine behind letting a tenant do something by *replying* to
-- a message, instead of only ever receiving one. First use: self-serve
-- onboarding entirely inside WhatsApp, as an alternative to the web link
-- in tenant_invite_links — deferred to V2, see docs/DECISIONS.md. Same
-- shape is meant to be reused later for "raise a complaint by replying"
-- and "confirm a payment by replying," both cut from MVP for now too.
--
-- Note on `expires_at`: WhatsApp Business Platform only allows free-form
-- messages from us for 24h after the tenant's last reply (a "session").
-- Outside that window we can't just message them again — we have to send
-- a new pre-approved template to re-open a session. This column is what a
-- resume job checks to decide "still mid-conversation" vs "went cold,
-- needs a fresh template," not a hard expiry of the tenant's data.
create table if not exists whatsapp_conversations (
  id uuid primary key default gen_random_uuid(),
  phone text not null, -- the WhatsApp number this conversation is with
  tenancy_id uuid references tenancies (id), -- resolved once the flow can identify which stay this is about
  flow text not null check (flow in ('tenant_onboarding', 'raise_complaint', 'confirm_payment')),
  current_step text not null default 'started',
  context jsonb not null default '{}', -- answers collected so far, e.g. {"emergency_contact_name": "..."}
  status text not null default 'active' check (status in ('active', 'completed', 'expired', 'abandoned')),
  last_message_at timestamptz not null default now(),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- One row per WhatsApp/SMS message actually sent — backs both the tenant
-- rent reminder and the Manager daily digest (Phase 4), so a digest is
-- never sent twice for the same day/event.
create table if not exists reminder_log (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users (id),
  channel text not null check (channel in ('whatsapp', 'sms')),
  kind text not null check (kind in ('tenant_rent_reminder', 'manager_daily_digest')),
  payload jsonb not null default '{}',
  sent_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Public discovery views — the tenant-facing "browse properties" screen.
-- These deliberately expose only listing-safe columns (no tenant/
-- financial data) and are owned by a privileged role, so they read
-- straight past the RLS policies below by design — that's the standard,
-- correct Postgres/Supabase pattern for a public view over RLS-protected
-- tables. Never add a column to either view without checking it's safe
-- for a signed-out stranger to see.
-- ---------------------------------------------------------------------

create or replace view public_property_listings as
select
  p.id,
  p.name,
  p.address,
  p.slug,
  p.amenities,
  p.cover_photo_url,
  count(b.id) filter (where b.status = 'vacant') as vacant_beds,
  min(b.listed_rent) filter (where b.status = 'vacant') as rent_from
from properties p
join rooms r on r.property_id = p.id
join beds b on b.room_id = r.id
group by p.id
having count(b.id) filter (where b.status = 'vacant') > 0;

create or replace view public_bed_listings as
select
  b.id as bed_id,
  r.property_id,
  r.room_no,
  b.bed_no,
  b.listed_rent,
  b.listed_deposit
from beds b
join rooms r on r.id = b.room_id
where b.status = 'vacant';

grant select on public_property_listings to anon, authenticated;
grant select on public_bed_listings to anon, authenticated;

-- ---------------------------------------------------------------------
-- Row Level Security — the actual permission boundary, not just the UI.
-- A Manager's queries are physically incapable of returning another
-- owner's data, independent of any frontend bug.
-- ---------------------------------------------------------------------

alter table organizations enable row level security;
alter table profiles enable row level security;
alter table tenant_profiles enable row level security;
alter table properties enable row level security;
alter table rooms enable row level security;
alter table beds enable row level security;
alter table tenancies enable row level security;
alter table tenant_invite_links enable row level security;
alter table whatsapp_conversations enable row level security;
alter table id_documents enable row level security;
alter table payments enable row level security;
alter table complaints enable row level security;
alter table reminder_log enable row level security;

-- Helper: the calling user's profile row, looked up once per policy check.
create or replace function auth_profile()
returns profiles
language sql
security definer
stable
as $$
  select * from profiles where id = auth.uid();
$$;

-- profiles: everyone can read their own row; Owner/Admin can read every
-- profile in their org; nobody updates role/org_id/property_scope directly
-- from the client (that's an Owner-only server action in a later phase).
create policy "read own profile" on profiles for select using (id = auth.uid());
create policy "owner reads org profiles" on profiles for select
  using ((select role from auth_profile()) = 'owner' and org_id = (select org_id from auth_profile()));

-- tenant_profiles: the tenant reads/writes their own; Owner/Manager can
-- read one only if that person currently has a tenancy in their org/scope
-- (support & verification, not open browsing of every tenant on the
-- platform).
create policy "tenant reads own tenant profile" on tenant_profiles for select using (id = auth.uid());
create policy "tenant writes own tenant profile" on tenant_profiles for insert
  with check (id = auth.uid() and (select role from auth_profile()) = 'tenant');
create policy "tenant updates own tenant profile" on tenant_profiles for update using (id = auth.uid());
create policy "owner reads org tenant profiles" on tenant_profiles for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.profile_id = tenant_profiles.id
      and p.org_id = (select org_id from auth_profile())
      and (select role from auth_profile()) = 'owner'
  ));
create policy "manager reads scoped tenant profiles" on tenant_profiles for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.profile_id = tenant_profiles.id
      and (select role from auth_profile()) = 'manager'
      and p.id = any (select property_scope from auth_profile())
  ));

-- organizations: readable by members of that org only.
create policy "org members read own org" on organizations for select
  using (id = (select org_id from auth_profile()));

-- properties: Owner/Admin sees every property in their org; Manager sees
-- only properties in their property_scope; Tenant has no direct access to
-- this table (browsing happens through the public views above; once
-- assigned, they only ever see their own tenancy/bed/payment/complaint
-- rows).
create policy "owner reads all org properties" on properties for select
  using ((select role from auth_profile()) = 'owner' and org_id = (select org_id from auth_profile()));
create policy "manager reads scoped properties" on properties for select
  using ((select role from auth_profile()) = 'manager' and id = any (select property_scope from auth_profile()));

-- rooms/beds inherit property scoping via a join back to properties.
create policy "owner reads all org rooms" on rooms for select
  using (exists (
    select 1 from properties p
    where p.id = rooms.property_id
      and p.org_id = (select org_id from auth_profile())
      and (select role from auth_profile()) = 'owner'
  ));
create policy "manager reads scoped rooms" on rooms for select
  using (exists (
    select 1 from properties p
    where p.id = rooms.property_id
      and (select role from auth_profile()) = 'manager'
      and p.id = any (select property_scope from auth_profile())
  ));

create policy "owner reads all org beds" on beds for select
  using (exists (
    select 1 from rooms r join properties p on p.id = r.property_id
    where r.id = beds.room_id
      and p.org_id = (select org_id from auth_profile())
      and (select role from auth_profile()) = 'owner'
  ));
create policy "manager reads scoped beds" on beds for select
  using (exists (
    select 1 from rooms r join properties p on p.id = r.property_id
    where r.id = beds.room_id
      and (select role from auth_profile()) = 'manager'
      and p.id = any (select property_scope from auth_profile())
  ));

-- tenancies: Owner (org-wide) and Manager (scoped) as above; a tenant
-- reads only their own stays, matched by the hard profile_id link (set
-- the moment they authenticate — either via the invite-link OTP step, or
-- immediately, since a self-requested tenancy can only ever be created by
-- an already-authenticated tenant in the first place).
create policy "owner reads all org tenancies" on tenancies for select
  using (exists (
    select 1 from beds b join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where b.id = tenancies.bed_id
      and p.org_id = (select org_id from auth_profile())
      and (select role from auth_profile()) = 'owner'
  ));
create policy "manager reads scoped tenancies" on tenancies for select
  using (exists (
    select 1 from beds b join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where b.id = tenancies.bed_id
      and (select role from auth_profile()) = 'manager'
      and p.id = any (select property_scope from auth_profile())
  ));
create policy "tenant reads own tenancies" on tenancies for select
  using (profile_id = auth.uid() and (select role from auth_profile()) = 'tenant');

-- A tenant can request a bed themselves (the cross-owner discovery path),
-- but only a pending request on themselves — never write anyone else's
-- tenancy, never write it as already active. Actually flipping the bed
-- from vacant to hold alongside this insert needs to happen atomically
-- (a Postgres function or a server route using `select ... for update`),
-- not as a second unguarded client write — otherwise two tenants could
-- both "win" the same bed. That function isn't written yet; this policy
-- just fixes what a tenant is allowed to submit once it exists.
create policy "tenant requests a tenancy" on tenancies for insert
  with check (
    profile_id = auth.uid()
    and (select role from auth_profile()) = 'tenant'
    and status = 'pending_approval'
    and source = 'tenant_requested'
  );

-- tenant_invite_links: staff-only (Owner org-wide, Manager scoped) — the
-- tenant themselves is not authenticated yet when they open the link, so
-- there is deliberately no policy granting them access here. The public
-- "complete your profile" page resolves a token via a server route using
-- the Supabase service-role key, which bypasses RLS by design for this one
-- lookup, then everything after OTP verification runs as the tenant's own
-- authenticated session under the policies above.
create policy "owner reads all org invite links" on tenant_invite_links for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.id = tenant_invite_links.tenancy_id
      and p.org_id = (select org_id from auth_profile())
      and (select role from auth_profile()) = 'owner'
  ));
create policy "manager reads scoped invite links" on tenant_invite_links for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.id = tenant_invite_links.tenancy_id
      and (select role from auth_profile()) = 'manager'
      and p.id = any (select property_scope from auth_profile())
  ));

-- whatsapp_conversations: staff-only visibility, and only once a
-- tenancy_id is resolved (so a Manager can see "Priya is stuck on the
-- ID-photo step" for support purposes). The bot itself always writes
-- through the service-role key from the webhook handler — same reasoning
-- as tenant_invite_links: no tenant/anon policy, on purpose.
create policy "owner reads all org whatsapp conversations" on whatsapp_conversations for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.id = whatsapp_conversations.tenancy_id
      and p.org_id = (select org_id from auth_profile())
      and (select role from auth_profile()) = 'owner'
  ));
create policy "manager reads scoped whatsapp conversations" on whatsapp_conversations for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.id = whatsapp_conversations.tenancy_id
      and (select role from auth_profile()) = 'manager'
      and p.id = any (select property_scope from auth_profile())
  ));

-- payments/complaints/id_documents follow the same tenancy-linkage
-- pattern; kept intentionally simple in Phase 0 (readable by the tenant's
-- own record + org Owner/scoped Manager) — write policies (who can insert
-- a payment/complaint) are added in Phase 3/5 alongside those features,
-- once the actual write flows exist to test them against.
create policy "owner reads all org payments" on payments for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.id = payments.tenancy_id
      and p.org_id = (select org_id from auth_profile())
      and (select role from auth_profile()) = 'owner'
  ));
create policy "manager reads scoped payments" on payments for select
  using (exists (
    select 1 from tenancies tc join beds b on b.id = tc.bed_id join rooms r on r.id = b.room_id join properties p on p.id = r.property_id
    where tc.id = payments.tenancy_id
      and (select role from auth_profile()) = 'manager'
      and p.id = any (select property_scope from auth_profile())
  ));
create policy "tenant reads own payments" on payments for select
  using (exists (
    select 1 from tenancies tc where tc.id = payments.tenancy_id and tc.profile_id = auth.uid()
  ));

comment on table tenant_profiles is 'Tenant identity that persists across every tenancy this person has, on any owner''s property. See "Cross-owner discovery + identity/tenancy split" in docs/DECISIONS.md.';
comment on table tenancies is 'One row per stay — a specific person at a specific bed, for a specific owner. Identity lives on profiles/tenant_profiles instead, so it survives a transfer or a move to a different owner. See docs/DECISIONS.md.';
comment on table id_documents is 'Plain ID-proof photo storage with a manual staff-checked flag, scoped per tenancy (not shared across owners). Deliberately not Aadhaar e-KYC — see docs/DECISIONS.md.';
comment on table reminder_log is 'Backs both tenant rent reminders and the Manager daily WhatsApp digest (Phase 4).';
comment on table tenant_invite_links is 'Magic-link tokens for tenant self-serve profile completion (staff-initiated path only). Resolved server-side with the service-role key, not via RLS. See "New tenant onboarding" in docs/DECISIONS.md.';
comment on table whatsapp_conversations is 'State machine for inbound WhatsApp reply-driven flows. V2, not MVP — see docs/DECISIONS.md. Written only by the webhook handler via the service-role key.';
comment on view public_property_listings is 'Tenant-facing discovery — every property on the platform with at least one vacant bed. Deliberately public: no RLS, listing-safe columns only.';
comment on view public_bed_listings is 'Tenant-facing discovery — vacant beds only, for the "inside a property" picker. Deliberately public: no RLS, listing-safe columns only.';
