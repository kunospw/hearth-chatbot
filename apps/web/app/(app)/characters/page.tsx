"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useMemo, useState } from "react";
import { useSession } from "@/components/providers/session";
import { CharacterAvatar } from "@/components/ui/avatar";
import { Card } from "@/components/ui/card";
import { PlusIcon, SearchIcon } from "@/components/ui/icons";
import { Overline } from "@/components/ui/overline";
import type { Character } from "@/lib/domain/types";
import { listCharacters } from "@/lib/repositories/characters";
import { sampleCharacters } from "@/lib/sample/characters";
import { getClientBackend } from "@/lib/supabase/client";

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 18) return "Good afternoon";
  return "Good evening";
}

function matches(c: Character, q: string): boolean {
  const s = q.toLowerCase();
  return (
    c.name.toLowerCase().includes(s) ||
    c.short.toLowerCase().includes(s) ||
    c.tags.some((t) => t.toLowerCase().includes(s))
  );
}

export default function CharactersPage() {
  const { configured, session } = useSession();
  const useReal = configured && !!session;
  const [query, setQuery] = useState("");

  const { data } = useQuery({
    queryKey: ["characters"],
    queryFn: () => listCharacters(getClientBackend()),
    enabled: useReal,
  });

  const all = useReal ? (data ?? []) : sampleCharacters;
  const shown = useMemo(
    () => (query ? all.filter((c) => matches(c, query)) : all),
    [all, query],
  );

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-1">
        <Overline>Hearth</Overline>
        <h1 className="t-display">{greeting()}</h1>
      </header>

      <label className="flex items-center gap-2 rounded-field border border-outline bg-surface px-3 min-h-12">
        <SearchIcon size={18} className="text-subtle" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search characters"
          className="w-full bg-transparent outline-none text-text placeholder:text-subtle text-[15px]"
        />
      </label>

      <section className="flex flex-col gap-3">
        <Overline>Characters</Overline>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
          {shown.map((c) => (
            <Link key={c.id} href={`/chat/c/${c.id}`} className="block">
              <Card className="flex flex-col gap-3 p-4 min-h-[210px] h-full hover:border-ink transition-colors">
                <CharacterAvatar character={c} size={56} radius={14} />
                <div className="flex flex-col gap-1 flex-1">
                  <div className="t-label">{c.name}</div>
                  <p className="t-caption line-clamp-2">{c.short}</p>
                </div>
                {c.tags[0] ? (
                  <span className="self-start rounded-full bg-raised px-2.5 py-1 t-caption text-muted">
                    {c.tags[0]}
                  </span>
                ) : null}
              </Card>
            </Link>
          ))}

          <button
            type="button"
            className="flex flex-col items-center justify-center gap-2 min-h-[210px] rounded-card border border-dashed border-outline text-muted hover:bg-surface transition-colors"
          >
            <PlusIcon />
            <span className="t-caption">Create a character</span>
          </button>
        </div>

        {shown.length === 0 ? (
          <p className="t-caption text-subtle">
            No characters match “{query}”.
          </p>
        ) : null}
      </section>
    </div>
  );
}
