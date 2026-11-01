// Minimal permissive CORS — these functions are only ever called from the
// Flutter app (mobile, no browser CORS enforcement) or curl/tests, but a
// preflight-safe header set costs nothing and avoids surprises if a web
// client (e.g. the future marketplace surface) ever calls one directly.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
