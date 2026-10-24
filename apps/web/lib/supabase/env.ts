// The app holds only the project URL and the public anon key. What a signed-in
// user can read or change is decided by row-level security; the model is only
// reachable through the edge functions. Mirrors lib/core/backend/backend_config.dart.

export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

/** True when both public Supabase vars are set. */
export const hasSupabaseEnv = Boolean(SUPABASE_URL && SUPABASE_ANON_KEY);

export function requireSupabaseEnv(): void {
  if (!hasSupabaseEnv) {
    throw new Error(
      "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and " +
        "NEXT_PUBLIC_SUPABASE_ANON_KEY in apps/web/.env.local (see .env.local.example).",
    );
  }
}
