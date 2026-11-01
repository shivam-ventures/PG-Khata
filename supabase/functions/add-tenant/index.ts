// PG Khata — add-tenant Edge Function.
//
// Replaces MockTenantsRepository.addTenant for the real backend. This is
// the ONE tenancy-creation path that genuinely needs the Admin API rather
// than a plain Postgres RPC: staff is adding a person who has never opened
// the app, so there is no auth.users row (and therefore no profiles row)
// to attach a tenancy to yet. See docs/backend-domain-model.md §11 and the
// comment atop supabase/migrations/20260922000011_functions_tenancy.sql.
//
// Flow:
//   1. Verify the caller (via their own JWT) is actually staff for the
//      target bed's property — done by asking the DATABASE, under the
//      caller's own RLS, rather than duplicating that logic here: if a
//      scoped SELECT for this bed comes back empty, they're not
//      authorized (RLS already filtered it out) or the bed doesn't exist.
//      Either way, deny.
//   2. Using the service role: find an existing profile for this phone
//      number, or create a brand-new auth user + profile if none exists.
//   3. Call create_tenancy_for_profile (service-role grant, migration 13)
//      to create the tenancy — the same function every other tenancy-
//      creation path uses, so the partial unique index (one active
//      tenancy per bed) and the audit trail are identical either way.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

interface AddTenantBody {
  name: string;
  phone: string;
  bedId: string;
  rentAmount: number;
  rentDueDay?: number;
  depositAmount?: number | null;
  moveInDate?: string; // ISO date, defaults to today in the DB function
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// profiles.phone is bare-10-digit everywhere in this app (seeded profiles,
// complete_invite_join); auth.users.phone must be E.164 for the Admin API.
// Both are derived from the same input here so they never disagree with
// the rest of the schema's convention.
function toBareDigits(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  return digits.length > 10 ? digits.slice(-10) : digits;
}

function toE164(phone: string): string {
  return `+91${toBareDigits(phone)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "missing authorization" }, 401);

  let body: AddTenantBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const { name, phone, bedId, rentAmount } = body;
  if (!name?.trim() || !phone?.trim() || !bedId || !rentAmount || rentAmount <= 0) {
    return json({ error: "name, phone, bedId and a positive rentAmount are required" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Step 1 — authorization, as the caller, under their own RLS.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: authorizedBed, error: bedError } = await callerClient
    .from("beds")
    .select("id, rooms!inner(property_id)")
    .eq("id", bedId)
    .maybeSingle();

  if (bedError) return json({ error: bedError.message }, 500);
  if (!authorizedBed) {
    return json({ error: "bed not found, or you are not authorized to add a tenant to it" }, 403);
  }

  const { data: callerAuth, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerAuth?.user) {
    return json({ error: "could not resolve the calling user" }, 401);
  }
  const staffUserId = callerAuth.user.id;

  // Step 2 onward — privileged operations via the service role.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const normalizedPhone = toBareDigits(phone.trim());
  const e164Phone = toE164(phone.trim());

  const { data: existingProfile, error: profileLookupError } = await adminClient
    .from("profiles")
    .select("id")
    .eq("phone", normalizedPhone)
    .eq("role", "tenant")
    .maybeSingle();

  if (profileLookupError) return json({ error: profileLookupError.message }, 500);

  let profileId: string;

  if (existingProfile) {
    profileId = existingProfile.id;
  } else {
    const { data: created, error: createUserError } = await adminClient.auth.admin.createUser({
      phone: e164Phone,
      phone_confirm: true, // staff-vouched, matches the current mock's "no OTP needed for a staff-added tenant" behavior
      user_metadata: { full_name: name.trim() },
    });

    if (createUserError) {
      // This phone already has SOME account (any role) — Supabase Auth
      // enforces phone uniqueness across the whole project, not per role.
      if (createUserError.message?.includes("already been registered")) {
        const { data: list, error: listError } = await adminClient.auth.admin.listUsers({ perPage: 200 });
        if (listError) return json({ error: listError.message }, 500);
        const found = list.users.find((u) => u.phone === e164Phone.replace("+", ""));
        if (!found) {
          return json({ error: "phone is already registered under a different role" }, 409);
        }

        // SECURITY: fixed 2026-09-25 — this used to upsert `role: "tenant"`
        // unconditionally onto whatever profile matched this phone number,
        // silently overwriting an existing Owner's or Manager's role the
        // moment any staff member (anywhere in the system) typed in their
        // phone number via Add Tenant. Check the existing profile's actual
        // role first and refuse to touch it if it differs — never let this
        // upsert change `role` on a profile that already has one.
        const { data: existingByAuthId, error: existingByAuthIdError } = await adminClient
          .from("profiles")
          .select("id, role")
          .eq("id", found.id)
          .maybeSingle();
        if (existingByAuthIdError) return json({ error: existingByAuthIdError.message }, 500);
        if (existingByAuthId && existingByAuthId.role !== "tenant") {
          return json(
            { error: "this phone number is already registered as a different role (not tenant)" },
            409,
          );
        }

        profileId = found.id;
      } else {
        return json({ error: createUserError.message }, 500);
      }
    } else if (!created?.user) {
      return json({ error: "could not create tenant account" }, 500);
    } else {
      profileId = created.user.id;
    }

    const { error: upsertProfileError } = await adminClient
      .from("profiles")
      .upsert(
        { id: profileId, role: "tenant", full_name: name.trim(), phone: normalizedPhone },
        { onConflict: "id" },
      );

    if (upsertProfileError) {
      return json({ error: upsertProfileError.message }, 500);
    }
  }

  const { data: tenancy, error: tenancyError } = await adminClient.rpc(
    "create_tenancy_for_profile",
    {
      p_profile_id: profileId,
      p_bed_id: bedId,
      p_rent_amount: rentAmount,
      p_rent_due_day: body.rentDueDay ?? 5,
      p_deposit_amount: body.depositAmount ?? null,
      p_move_in_date: body.moveInDate ?? new Date().toISOString().slice(0, 10),
      p_source: "staff_created",
      p_created_by: staffUserId,
    },
  );

  if (tenancyError) {
    // The partial unique index (one active tenancy per bed) surfaces here
    // as a unique_violation if two staff members raced on the same bed.
    return json({ error: tenancyError.message }, 409);
  }

  return json({ tenancy, profileId }, 201);
});
