import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { BackendApi } from "@/lib/backend/api";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./env";

// Browser Supabase client (singleton) + a BackendApi bound to it. Use from
// client components for interactive reads/writes and edge-function streaming.

let client: SupabaseClient | undefined;

export function getBrowserClient(): SupabaseClient {
  if (!client) {
    // In the signed-out preview (no env) the client is constructed but never
    // called — session/repos are gated on hasSupabaseEnv. Use placeholders so
    // createBrowserClient doesn't throw on empty values.
    const url = SUPABASE_URL || "http://localhost:54321";
    const key = SUPABASE_ANON_KEY || "preview-anon-key-placeholder";
    client = createBrowserClient(url, key);
  }
  return client;
}

let api: BackendApi | undefined;

export function getClientBackend(): BackendApi {
  if (!api) {
    api = new BackendApi(getBrowserClient(), SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return api;
}
