import { redirect } from "next/navigation";
import { createClient } from "@/services/supabase/server";
import { ROLE_HOME, type Role } from "@/lib/constants";
import { isDevBypassEnabled, mockProfileFor } from "@/lib/dev-bypass";

/**
 * Server-side guard for each role's layout.tsx: resolves the signed-in
 * user's profile (role + org + property_scope) and redirects if they're
 * not signed in or don't hold `expectedRole`.
 *
 * Role and property_scope are also enforced at the database layer via
 * Postgres Row Level Security (see supabase/schema.sql) — this guard is
 * about routing UX, not the actual security boundary.
 */
export async function requireRole(expectedRole: Role) {
  // Dev-only shortcut so the UI can be previewed with zero Supabase setup —
  // see src/lib/dev-bypass.ts. Never true unless NEXT_PUBLIC_DEV_BYPASS_AUTH
  // is explicitly set, and it's a loud, commented, easy-to-remove flag.
  if (isDevBypassEnabled()) return mockProfileFor(expectedRole);

  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user.id).single();

  if (!profile) redirect("/login");
  if (profile.role !== expectedRole) redirect(ROLE_HOME[profile.role]);

  return profile;
}
