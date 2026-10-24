import { type CookieOptions, createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import { SUPABASE_ANON_KEY, SUPABASE_URL, hasSupabaseEnv } from "@/lib/supabase/env";

// Refreshes the Supabase auth session on every request and writes the rotated
// cookies back onto the response, so Server Components always see a live
// session. Standard @supabase/ssr middleware pattern.
export async function middleware(request: NextRequest) {
  if (!hasSupabaseEnv) return NextResponse.next({ request });

  let response = NextResponse.next({ request });

  const supabase = createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(
        cookiesToSet: { name: string; value: string; options: CookieOptions }[],
      ) {
        for (const { name, value } of cookiesToSet) {
          request.cookies.set(name, value);
        }
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  // Touch the session so it refreshes if near expiry. Do not run code between
  // createServerClient and getUser (per @supabase/ssr guidance).
  await supabase.auth.getUser();

  return response;
}

export const config = {
  matcher: [
    // Everything except Next internals and static assets.
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ttf|woff2?)$).*)",
  ],
};
