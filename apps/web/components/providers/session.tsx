"use client";

import type { Session, User } from "@supabase/supabase-js";
import { createContext, useContext, useEffect, useState } from "react";
import { getSession, onAuthChange } from "@/lib/auth/auth";
import { hasSupabaseEnv } from "@/lib/supabase/env";

// Tracks the Supabase auth session on the client. When Supabase isn't
// configured (no env), the app runs in a signed-out preview with sample data.

interface SessionState {
  session: Session | null;
  user: User | null;
  loading: boolean;
  /** Whether Supabase env is set at all. */
  configured: boolean;
}

const SessionContext = createContext<SessionState>({
  session: null,
  user: null,
  loading: true,
  configured: false,
});

export function SessionProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<SessionState>({
    session: null,
    user: null,
    loading: hasSupabaseEnv,
    configured: hasSupabaseEnv,
  });

  useEffect(() => {
    if (!hasSupabaseEnv) return;
    let active = true;
    getSession()
      .then((session) => {
        if (active) {
          setState({ session, user: session?.user ?? null, loading: false, configured: true });
        }
      })
      .catch(() => {
        if (active) setState((s) => ({ ...s, loading: false }));
      });
    const unsubscribe = onAuthChange((session) => {
      setState({ session, user: session?.user ?? null, loading: false, configured: true });
    });
    return () => {
      active = false;
      unsubscribe();
    };
  }, []);

  return <SessionContext.Provider value={state}>{children}</SessionContext.Provider>;
}

export const useSession = () => useContext(SessionContext);
