import { type CookieOptions, createServerClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { cookies } from "next/headers";
import { BackendApi } from "@/lib/backend/api";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./env";

// Server Supabase client bound to the request cookies (Next 15: cookies() is
// async). Use from Server Components, Route Handlers and Server Actions.

export async function createServerSupabase(): Promise<SupabaseClient> {
  const cookieStore = await cookies();
  return createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(
        cookiesToSet: { name: string; value: string; options: CookieOptions }[],
      ) {
        // In a Server Component the cookie store is read-only; the middleware
        // refreshes the session instead, so swallowing here is correct.
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          /* called from a Server Component — handled by middleware */
        }
      },
    },
  });
}

export async function getServerBackend(): Promise<BackendApi> {
  const sb = await createServerSupabase();
  return new BackendApi(sb, SUPABASE_URL, SUPABASE_ANON_KEY);
}
