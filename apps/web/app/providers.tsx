"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { PrefsProvider } from "@/components/providers/prefs";
import { SessionProvider } from "@/components/providers/session";
import { ThemeProvider } from "@/components/providers/theme";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: { queries: { staleTime: 30_000, refetchOnWindowFocus: false } },
      }),
  );

  return (
    <QueryClientProvider client={queryClient}>
      <SessionProvider>
        <ThemeProvider>
          <PrefsProvider>{children}</PrefsProvider>
        </ThemeProvider>
      </SessionProvider>
    </QueryClientProvider>
  );
}
