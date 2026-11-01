// PG Khata — resolve-invite Edge Function.
//
// Resolves a `/join/:token` link to the safe, display-only details
// JoinInviteScreen shows BEFORE the person is authenticated (property
// name, room, bed, rent, an assigned manager's name) — see
// docs/backend-domain-model.md §9/§12.4: tenant_invite_links has
// deliberately no anon/tenant RLS policy, so this lookup runs under the
// service role instead, exactly like the pre-pivot schema's own stated
// reasoning for the same pattern.
//
// Once the person has verified their own phone OTP (via Supabase Auth
// directly, not this function), completing the join calls the
// complete_invite_join Postgres RPC as their now-authenticated self — that
// part needs no service role at all, see migration 11.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const token = url.searchParams.get("token") ?? (await req.json().catch(() => ({})))?.token;

  if (!token) return json({ error: "token is required" }, 400);

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: invite, error } = await adminClient
    .from("tenant_invite_links")
    .select(
      `token, expires_at, used_at,
       beds!inner (
         label,
         rooms!inner (
           room_number, rent_per_bed, property_id,
           properties!inner ( name )
         )
       )`,
    )
    .eq("token", token)
    .maybeSingle();

  if (error) return json({ error: error.message }, 500);
  if (!invite) return json({ error: "invite_not_found" }, 404);
  if (invite.used_at) return json({ error: "invite_already_used" }, 410);
  if (new Date(invite.expires_at) < new Date()) return json({ error: "invite_expired" }, 410);

  // deno-lint-ignore no-explicit-any
  const bed = invite.beds as any;
  const room = bed.rooms;
  const property = room.properties;

  const { data: manager } = await adminClient
    .from("property_managers")
    .select("manager_user_id, profiles!inner ( full_name )")
    .eq("property_id", room.property_id)
    .is("unassigned_at", null)
    .order("assigned_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  return json({
    token: invite.token,
    propertyName: property.name,
    room: room.room_number,
    bed: bed.label,
    rentPerBed: room.rent_per_bed,
    // deno-lint-ignore no-explicit-any
    managerName: (manager as any)?.profiles?.full_name ?? "the PG Khata team",
  });
});
