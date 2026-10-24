import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { BackendApi } from "@/lib/backend/api";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./env";

// Browser Supabase client (singleton) + a BackendApi bound to it. Use from
// client components for interactive reads/writes and edge-function streaming.

let client: SupabaseClient | undefined;

export function getBrowserClient(): SupabaseClient {
  if (!client) {
    client = createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY);
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
