# Product & engineering decisions log

Running log of decisions that change scope, kept next to the code so the
reasoning doesn't get lost in chat history. Add to this file, don't rewrite
history in it.

## 2026-09-14 — Skip Aadhaar e-KYC for Phase 0-2; store a plain ID photo instead

**Decision:** Tenant identity verification in the MVP is a plain uploaded
photo (front/back of any ID) with a manual "checked by staff" toggle —
`id_documents` table. No Aadhaar number is captured anywhere. No UIDAI
authentication/e-KYC API is called.

**Why:** Real Aadhaar authentication (AUA/KUA) is legally restricted to
UIDAI-notified entities (mainly banks/NBFCs) — a PG-management startup
cannot register directly, and the realistic paths (Sub-KUA via a licensed
vendor, or Aadhaar Paperless Offline e-KYC) both add real integration and
compliance work that isn't worth taking on before the core product is
proven. See the original strategic review, Section 4.1, for the full
regulatory picture.

**Revisit when:** the product has real paying owners and identity
verification quality becomes a stated blocker to a sale — at that point,
Aadhaar Paperless Offline e-KYC / DigiLocker (self-served by the tenant,
no AUA license needed) is the next step up, not raw photo storage.

## 2026-09-14 — Manager gets a WhatsApp daily digest too, not just Tenant reminders

**Decision:** The Phase 4 reminders feature (per the roadmap) now explicitly
includes a Manager-facing daily WhatsApp digest — rent due today, overdue
count, open complaints — alongside the Tenant rent reminder that was
already planned.

**What's in Phase 0 already:** the `reminder_log` table (so a digest is
never double-sent) and the Manager dashboard's "Today" stat row (rent due
today / overdue / open complaints / vacant beds) — the exact numbers the
digest will summarize. Building the screen and the digest job against the
same query means Phase 4 is "format this for WhatsApp, send," not new
logic.

**Not built yet:** the actual cron job and WhatsApp API call — that needs
real payments/complaints data to summarize, which lands in Phase 3 and 5
respectively. Sequencing this correctly (screen first, message job once
there's real data) avoids building a digest that has nothing to say.

## 2026-09-14 — Added a dev-only auth bypass for zero-setup preview

**Decision:** `NEXT_PUBLIC_DEV_BYPASS_AUTH=true` (`src/lib/dev-bypass.ts`)
skips real Supabase auth and swaps the login screen for a role picker, so
the UI can be clicked through with no Supabase project at all. A loud
"Dev preview mode" banner stays on screen whenever it's active
(`role-shell.tsx`), and `middleware.ts`/`lib/auth.ts` both route around
real auth only when the flag is explicitly set.

**Why:** fastest possible path to actually seeing Phase 0 running, before
doing any Supabase setup. Real auth code is untouched — this is a pure
add-on, not a shortcut taken inside the real flow.

**Remove when:** real auth is set up and no longer needs a no-setup
preview path — delete `src/lib/dev-bypass.ts` and its three call sites
(`middleware.ts`, `lib/auth.ts`, `app/page.tsx`, `role-shell.tsx`).

## 2026-09-15 — New tenant onboarding: two paths, self-serve profile via magic link

**Note:** written when there was only one combined `tenants` table; the
"Cross-owner discovery + identity/tenancy split" decision further below
splits that into `tenancies` (a stay) + `profiles`/`tenant_profiles`
(identity), and adds a third, tenant-initiated entry path alongside the
two below. Everything here about the self-serve completion step itself
still holds — it just now runs against `tenancies` instead of `tenants`,
and "a tenant record is always created by staff first" is true only for
the two paths below, not the tenant-initiated one added later.

**Decision:** A tenant record is always created by staff (Manager/Owner) first
— a tenant never signs up cold — but finishes their own profile. Two entry
paths, one shared self-serve step:

- **Same-day move-in** (tenant is standing in front of the Manager): pick a
  vacant bed, enter name/phone/rent/deposit, bed flips `vacant → occupied`
  immediately, tenant status starts at `pending_profile`.
- **Book-ahead** (tenant reserves before moving in): pick a bed, set
  `expected_move_in_date`, bed flips `vacant → hold` (status already existed
  in the Phase 0 schema, just unused until now) so it stops showing as
  available without being occupied yet. Same `pending_profile` status.

Either way, staff entry is deliberately minimal — name, phone, bed, rent,
deposit amount, expected/actual move-in date. Everything personal is the
tenant's own job: a `tenant_invite_links` row is created (a random token,
7-day expiry) and its link is sent over WhatsApp. Opening it walks the
tenant through: verify their own phone via OTP (this is also their first
real login), fill emergency contact, upload their own ID photo
(`id_documents`, same non-Aadhaar flow already decided), read and accept
the house rules/agreement (`agreement_accepted_at`), and see their deposit
amount. Finishing sets `profile_completed_at` and flips tenant `status` to
`active`; on the book-ahead path, staff confirming actual arrival is what
flips the bed `hold → occupied` (deliberately a separate, manual step —
plans fall through, and a bed shouldn't read "occupied" until someone is
actually in it).

**Why a magic link and not just an app login:** the tenant has nothing to
log into yet — the invite link's token is how an unauthenticated person is
matched to the right pending tenant record (resolved server-side with the
Supabase service-role key, bypassing RLS for that one lookup only). Every
step after phone OTP verification runs as their own authenticated session
under the normal RLS policies, so this doesn't weaken the permission
boundary — it's a bootstrap for the one moment before they have an account.
This is the "Magic-link tenant view" backlog idea, brought forward and
merged with "Digital move-in acknowledgment" — both were solving pieces of
the same gap.

**Schema additions:** `tenants.status` (`pending_profile` / `active` /
`notice_period` / `moved_out`), `expected_move_in_date`,
`security_deposit_amount`, `security_deposit_collected_at`,
`emergency_contact_name/phone`, `agreement_accepted_at`,
`profile_completed_at`, `profile_id` (links to `profiles` once OTP'd),
`created_by`; new `tenant_invite_links` table.

**Not built yet:** the actual "Add tenant" staff screen, the public
self-serve profile-completion page, and the WhatsApp send of the invite
link — this decision fixes the shape (schema + flow) so Phase 1 (Properties/
Rooms/Occupancy, which includes Add Tenant) and Phase 2 build straight
against it instead of retrofitting later. Security-deposit *collection*
(marking `security_deposit_collected_at`) reuses the Phase 3 payments UI
once that exists — deposit isn't a payments-table row, since it isn't rent
for a period.

## 2026-09-15 — Tenant self-serve profile: WhatsApp chat as well as the web link, not instead of it

**Status: deferred to V2 — see the scope-check decision below.** v1 ships
the in-app path only; this entry stands as the record of the WhatsApp-chat
design for when it's picked back up.

**Decision:** The invite message a new tenant gets offers two ways to
finish their own profile, both landing on the exact same schema/state:

- **Reply in WhatsApp** — "Reply START" opens a fully conversational
  flow: the bot asks name/emergency-contact one message at a time, the
  tenant sends their ID photo straight from their gallery, and a short
  linked page is used only for the one part that's genuinely worse as
  chat bubbles — reading and accepting the full house rules.
- **Tap the link** — the existing `tenant_invite_links` web page, for a
  tenant who'd rather fill a form than answer questions one at a time.

Whichever path they take writes the same `tenants` columns
(`emergency_contact_*`, `profile_completed_at`, `agreement_accepted_at`,
`status → active`) — the rest of the app never needs to know which
channel a tenant onboarded through.

**Why not WhatsApp-only:** the first message to an unresponsive tenant has
to be a pre-approved WhatsApp template (a business can't free-text someone
who hasn't messaged first) — replying opens a 24-hour free-form session,
not a permanent one. Going quiet mid-flow past that window means the bot
has to re-send a template to resume, not just DM them. That's a fine
constraint for a short flow, but it's why the web link stays as a fallback
that doesn't expire the same way, and why the schema tracks conversation
state explicitly instead of assuming a chat just picks back up.

**Why this is more than an onboarding feature:** it's the first inbound
WhatsApp flow — replies driving real writes, not just reminders going out.
The `whatsapp_conversations` table is deliberately generic (a `flow`
column, not a table per flow) so **"raise a complaint by replying"** and
**"confirm a payment by replying"** — both already in the backlog below —
reuse the same conversation-state engine instead of each inventing one.

**Schema addition:** `whatsapp_conversations` (phone, tenant_id, flow,
current_step, context jsonb, status, expires_at). Staff-only RLS, same
reasoning as `tenant_invite_links` — the bot writes via the service-role
key from the webhook handler, not as an authenticated tenant session.

**Not built yet:** the actual webhook handler, the step-by-step question
script per flow, and the BSP template approval (AiSensy/Gupshup) — this
fixes the shape so Phase 2 (onboarding) and Phase 4/5 (complaints,
payments) build against one engine instead of three.

## 2026-09-15 — Scope check: onboarding ships in-app for v1; Owner/Manager WhatsApp Q&A and inbound reply-flows cut from MVP

**Decision:**

- Tenant self-serve profile completion for v1 happens **inside the
  application itself** — the same Next.js app a tenant already has a
  dashboard in — reached via the `tenant_invite_links` magic link. Tenant
  opens/installs the app, verifies by OTP, finishes their profile there.
  Not a bare standalone webpage, and not the WhatsApp-chat version.
- The **WhatsApp-native chat onboarding** in the decision above is real
  and worth building, but is **V2, not MVP**. The `whatsapp_conversations`
  schema stays exactly as designed so nothing changes when it's picked up
  — no webhook or bot code is written until v1 has real tenant usage.
- The **Owner/Manager WhatsApp Q&A assistant** ("ask a doubt over
  WhatsApp") is **cut from scope entirely for now**, not deferred-with-a-
  date. It needs an AI layer with data-grounding and guardrails (a wrong
  answer about rent/deposit costs more trust than it builds), and it
  doesn't address the product's actual known adoption risk — owners/
  managers not using the tool at all — which good in-app UX solves more
  safely and cheaply. Revisit only if real usage shows a specific,
  recurring question in-app help genuinely can't answer.
- **Complaint-by-reply and payment-confirm-by-reply** (inbound WhatsApp
  actions) are cut from MVP for the same reason as the Q&A bot — same
  underlying infra cost (webhook, conversation state, BSP template
  approval), no validated need yet. Outbound WhatsApp — tenant reminders,
  Manager daily digest — is unaffected and stays in Phase 4 as planned.

**Why:** three parallel interaction surfaces (app, structured WhatsApp
bot, freeform WhatsApp Q&A) before Phase 1's core data model even ships is
building breadth before the one real unknown — will an owner actually
replace their register/Excel/WhatsApp-group habit with this at all — is
proven. Cutting here doesn't lose the ideas; this log and the schema
already in place are the record of exactly what to pick back up, and why,
once real usage justifies it.

## 2026-09-15 — Cross-owner discovery + identity/tenancy split

**Decision:** PG Khata's tenant app is a platform-wide discovery surface,
not a private tool scoped to one owner. Downloading the app and opening it
cold shows every property across every owner on PG Khata with a vacant
bed; a shared link (`/join/<property-slug>`) is a shortcut that presets
one property instead of showing the full list. This is a materially
bigger decision than earlier onboarding work — it's the difference between
"an owner's private ops tool" and "the way a tenant finds a PG at all" —
so two structural changes went with it instead of being patched in later:

- **Tenant identity split from tenancy.** A person's name, phone,
  emergency contact (`profiles` / new `tenant_profiles`) now lives
  independently of any specific stay (new `tenancies` table, replacing the
  old combined `tenants` table). Reason: a tenant can now plausibly have
  stays with *different owners* over their lifetime, not just different
  properties of one owner — so identity has to survive a move between
  organizations, not just between beds.
- **ID documents stay scoped per tenancy, not per identity.** A document
  uploaded for Owner A's PG is never visible to Owner B just because it's
  the same person — each org only ever sees what was uploaded within its
  own relationship with that tenant. A same-org transfer to a new bed can
  reuse the existing upload as an app-layer convenience without weakening
  this default; a move to a different owner asks for it again. This is a
  deliberate privacy line now that "the same tenant, different owner" is a
  real, expected case rather than an edge case.
- **New discovery views** (`public_property_listings`, `public_bed_listings`)
  expose only listing-safe columns (name, address, amenities, vacant-bed
  count, advertised rent/deposit) with no RLS — the standard Supabase
  pattern for a public view over otherwise-protected tables. Advertised
  rent (`beds.listed_rent/listed_deposit`) is deliberately separate from
  `tenancies.rent_amount`, since what's agreed with an actual tenant can
  differ from what's advertised.
- **A tenant can now request a bed themselves** — `tenancies.source =
  'tenant_requested'`, starting at `status = 'pending_approval'` instead of
  `pending_profile`, since nobody on staff has agreed to it yet. Owner/
  Manager approves or declines (declined kept as a row, not deleted, so a
  lead isn't silently lost); approving moves it to `pending_profile` and
  the exact same self-serve completion flow already built takes over.
  Staff-initiated tenancies are unaffected — they still start at
  `pending_profile` directly, since a Manager creating the record already
  means someone decided in person.

**Why split identity now instead of later:** retrofitting this after
tenant data already exists means migrating real people's records under
time pressure, with a real risk of duplicating or losing documents in the
process. Doing it before Phase 1 build starts costs a schema pass, not a
migration.

**Not built yet:** the atomic "claim this bed" function — a tenant's
request and the bed's `vacant → hold` flip need to happen in one
transaction (a Postgres function using `select ... for update`, or a
server route), not two separate client writes, or two tenants could both
"win" the same bed in a race. The RLS insert policy fixes what a tenant is
*allowed* to submit; it doesn't make the claim atomic by itself — that's
flagged directly in the schema comment so it isn't missed when the actual
"browse and request" screen gets built.

## Product ideas backlog (not scheduled yet)

Captured as they come up in conversation — triage into a real phase when
picked up, don't build speculatively:

- **One-tap WhatsApp receipt** for every payment, cash included — cheap to
  build once Phase 3 exists, and one of the strongest trust-builders in
  the whole product (a Manager entering a cash payment can also send a
  receipt, which is what actually makes "we track cash" credible to a
  tenant and to the owner).
- **Owner weekly digest** (not just Manager daily) — a cross-property
  WhatsApp summary for the actual paying buyer, separate from the
  Manager's daily action-item digest.
- **Manager nudge, not nag:** if a Manager hasn't logged any payment in
  an unusually long stretch for that property, a gentle WhatsApp check-in
  — framed as "need a hand?", never as an accusation (see the earlier
  review's note on "transparency" reading as surveillance).
- **Move-out / security-deposit settlement flow** — currently missing
  from the whole plan, and it's the single most dispute-prone moment in
  the tenant lifecycle. Natural trust-building feature once core rent
  tracking exists.
- ~~Magic-link tenant view~~ / ~~Digital move-in acknowledgment~~ — promoted
  into the "New tenant onboarding" decision above (2026-09-15).
- **Offline-queue indicator** ("3 payments waiting to sync") for the
  Manager's add-payment flow once real offline support is built — small
  UI detail, large trust impact on patchy Wi-Fi.
