"use client";

import { useQuery } from "@tanstack/react-query";
import { useSession } from "@/components/providers/session";
import { listConversations } from "@/lib/repositories/conversations";
import { getClientBackend } from "@/lib/supabase/client";

export function useConversations() {
  const { configured, session } = useSession();
  const useReal = configured && !!session;
  const { data, isLoading } = useQuery({
    queryKey: ["conversations"],
    queryFn: () => listConversations(getClientBackend()),
    enabled: useReal,
  });
  return { conversations: useReal ? (data ?? []) : [], useReal, loading: useReal && isLoading };
}
