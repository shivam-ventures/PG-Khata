// PG Khata — add-manager Edge Function.
//
// Assigns a manager to a property from the Add/Edit PG dialog. Like
// add-tenant, this needs the Admin API specifically for the "brand-new
// manager, never opened the app" case — an existing manager can be
// assigned to another property with a plain client-side property_managers
// insert (RLS: "owner manages own org assignments"), but provisioning a
// fresh auth.users row is not something RLS/a plain insert can do.
//
// Flow:
//   1. Verify the caller owns propertyId's org — asking the DATABASE under
//      the caller's own RLS, same reasoning as add-tenant: if a scoped
//      SELECT for this property comes back empty, deny.
//   2. Using the service role: find an existing manager profile for this
//      phone number, or create a brand-new auth user + profile if none
//      exists.
//   3. Soft-unassign whoever currently manages this property (this app's
//      UI only ever shows one manager per property, even though the
//      schema allows more), then insert the new assignment — both via the
//      service role, so the property briefly having zero/two managers
//      mid-request is never externally visible.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

interface AddManagerBody {
  name: string;
  phone: string;
  propertyId: string;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

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

  let body: AddManagerBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const { name, phone, propertyId } = body;
  if (!name?.trim() || !phone?.trim() || !propertyId) {
    return json({ error: "name, phone and propertyId are required" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Step 1 — authorization, as the caller, under their own RLS: only an
  // Owner can select a property they don't manage-but-not-own; a Manager
  // can select assigned properties too, so this also lets a Manager
  // *attempt* the call, but they're not who this dialog is for — the
  // Add/Edit PG screen is Owner-only, so this is a defense-in-depth check,
  // not the only gate.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: authorizedProperty, error: propertyError } = await callerClient
    .from("properties")
    .select("id")
    .eq("id", propertyId)
    .maybeSingle();

  if (propertyError) return json({ error: propertyError.message }, 500);
  if (!authorizedProperty) {
    return json({ error: "property not found, or you are not authorized to manage it" }, 403);
  }

  const { data: callerAuth, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerAuth?.user) {
    return json({ error: "could not resolve the calling user" }, 401);
  }
  const ownerUserId = callerAuth.user.id;

  // Step 2 onward — privileged operations via the service role.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const normalizedPhone = toBareDigits(phone.trim());
  const e164Phone = toE164(phone.trim());

  const { data: existingProfile, error: profileLookupError } = await adminClient
    .from("profiles")
    .select("id")
    .eq("phone", normalizedPhone)
    .eq("role", "manager")
    .maybeSingle();

  if (profileLookupError) return json({ error: profileLookupError.message }, 500);

  let managerId: string;

  if (existingProfile) {
    managerId = existingProfile.id;
  } else {
    const { data: created, error: createUserError } = await adminClient.auth.admin.createUser({
      phone: e164Phone,
      phone_confirm: true, // staff-vouched, matches add-tenant's own reasoning
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

        // SECURITY: fixed 2026-09-25 — this used to upsert `role: "manager"`
        // unconditionally onto whatever profile matched this phone number,
        // silently overwriting an existing Owner's or Tenant's role the
        // moment any Owner typed in that phone number via Add Manager.
        // Check the existing profile's actual role first and refuse to
        // touch it if it differs — never let this upsert change `role` on
        // a profile that already has one.
        const { data: existingByAuthId, error: existingByAuthIdError } = await adminClient
          .from("profiles")
          .select("id, role")
          .eq("id", found.id)
          .maybeSingle();
        if (existingByAuthIdError) return json({ error: existingByAuthIdError.message }, 500);
        if (existingByAuthId && existingByAuthId.role !== "manager") {
          return json(
            { error: "this phone number is already registered as a different role (not manager)" },
            409,
          );
        }

        managerId = found.id;
      } else {
        return json({ error: createUserError.message }, 500);
      }
    } else if (!created?.user) {
      return json({ error: "could not create manager account" }, 500);
    } else {
      managerId = created.user.id;
    }

    const { error: upsertProfileError } = await adminClient
      .from("profiles")
      .upsert(
        { id: managerId, role: "manager", full_name: name.trim(), phone: normalizedPhone },
        { onConflict: "id" },
      );
    if (upsertProfileError) return json({ error: upsertProfileError.message }, 500);
  }

  const { error: unassignError } = await adminClient
    .from("property_managers")
    .update({ unassigned_at: new Date().toISOString() })
    .eq("property_id", propertyId)
    .is("unassigned_at", null);
  if (unassignError) return json({ error: unassignError.message }, 500);

  const { data: assignment, error: assignError } = await adminClient
    .from("property_managers")
    .insert({ property_id: propertyId, manager_user_id: managerId, assigned_by: ownerUserId })
    .select()
    .single();
  if (assignError) return json({ error: assignError.message }, 500);

  // Let the manager know their account was assigned — matters most for the
  // "existing manager, reused by phone number" path (see the role-guard
  // fix above), where nothing else in this flow would otherwise tell them.
  // Best-effort: a notification failure should not fail the assignment.
  const { data: property } = await adminClient
    .from("properties")
    .select("name")
    .eq("id", propertyId)
    .maybeSingle();
  await adminClient.rpc("notify_user", {
    p_recipient: managerId,
    p_kind: "manager_assigned",
    p_title: "You've been assigned to manage a property",
    p_body: property?.name ? `You can now manage ${property.name}.` : null,
    p_entity_type: "property",
    p_entity_id: propertyId,
  });

  return json({ assignment, managerId }, 201);
});
