// Shared HTTP plumbing for the edge functions (Deno).
// CORS is open: the Authorization header, not the origin, is what protects these.
export const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

export function withCors(res: Response): Response {
  const h = new Headers(res.headers);
  for (const [k, v] of Object.entries(CORS_HEADERS)) h.set(k, v);
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
}

/** The bearer token of a request, or null. */
export function bearerToken(auth: string | null): string | null {
  return auth?.startsWith('Bearer ') ? auth.slice(7).trim() || null : null;
}
