import type { Role } from "@/lib/constants";

/**
 * DEV-ONLY preview shortcut — lets you click through the Owner/Manager/
 * Tenant dashboards with zero Supabase setup (no project, no schema, no
 * SMS provider). It is used ONLY by src/lib/auth.ts (requireRole) and
 * src/app/page.tsx, and only when NEXT_PUBLIC_DEV_BYPASS_AUTH=true is set
 * in .env.local.
 *
 * Nothing about real auth changes: with the flag unset (or false), every
 * route goes through the real Supabase phone-OTP flow exactly as before.
 * Middleware also short-circuits when this is on (src/middleware.ts) so a
 * missing Supabase project never blocks the preview.
 *
 * Delete this file and its two call sites once real auth is set up and
 * this is no longer needed — it should never be relied on past Phase 0.
 */
export function isDevBypassEnabled() {
  return process.env.NEXT_PUBLIC_DEV_BYPASS_AUTH === "true";
}

export function mockProfileFor(role: Role) {
  return {
    id: "dev-preview-user",
    org_id: "dev-preview-org",
    role,
    full_name: "Preview User",
    phone: "+910000000000",
    property_scope: [] as string[],
    created_at: new Date().toISOString(),
  };
}
