"use client";

import { useQuery } from "@tanstack/react-query";
import { useSession } from "@/components/providers/session";
import type { Character } from "@/lib/domain/types";
import { listCharacters } from "@/lib/repositories/characters";
import { sampleCharacters } from "@/lib/sample/characters";
import { getClientBackend } from "@/lib/supabase/client";

// Resolves characters from the backend when signed in, else the sample set
// (signed-out preview). Shared by the home, detail and editor screens.

export function useCharacters() {
  const { configured, session } = useSession();
  const useReal = configured && !!session;
  const { data, isLoading } = useQuery({
    queryKey: ["characters"],
    queryFn: () => listCharacters(getClientBackend()),
    enabled: useReal,
  });
  const characters: Character[] = useReal ? (data ?? []) : sampleCharacters;
  return { characters, useReal, loading: useReal && isLoading };
}

export function useCharacter(id: string) {
  const { characters, useReal, loading } = useCharacters();
  return { character: characters.find((c) => c.id === id) ?? null, useReal, loading };
}
