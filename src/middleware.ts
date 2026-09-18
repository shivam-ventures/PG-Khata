import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/services/supabase/middleware";
import { isDevBypassEnabled } from "@/lib/dev-bypass";

const PUBLIC_PATHS = ["/login"];

export async function middleware(request: NextRequest) {
  // Dev-only preview shortcut (see src/lib/dev-bypass.ts) — skip Supabase
  // session handling entirely so a missing/placeholder project never blocks
  // the UI preview. Every route's own requireRole() call still runs.
  if (isDevBypassEnabled()) return NextResponse.next();

  const { response, user } = await updateSession(request);

  const isPublic = PUBLIC_PATHS.some((p) => request.nextUrl.pathname.startsWith(p));

  if (!user && !isPublic) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return Response.redirect(url);
  }

  return response;
}

export const config = {
  matcher: [
    /*
     * Run on every route except static assets and Next internals.
     * Role-level access (owner vs manager vs tenant) is checked per-layout
     * via requireRole() in lib/auth.ts, and enforced for real by Postgres
     * Row Level Security — this only handles "signed in at all".
     */
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|webp)$).*)",
  ],
};
