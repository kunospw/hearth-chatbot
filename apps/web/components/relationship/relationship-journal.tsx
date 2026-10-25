"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useCharacter } from "@/components/characters/use-character";
import { Card } from "@/components/ui/card";
import { ArrowLeftIcon } from "@/components/ui/icons";
import { Overline } from "@/components/ui/overline";
import { ensureRelationship } from "@/lib/relationship/backend";
import type { Relationship } from "@/lib/relationship/types";
import { getClientBackend } from "@/lib/supabase/client";
import { timeLabel } from "@/lib/util/time";

const METERS: { key: keyof Relationship["values"]; label: string; color: string }[] = [
  { key: "trust", label: "Trust", color: "var(--meter-trust)" },
  { key: "affection", label: "Affection", color: "var(--meter-affection)" },
  { key: "attraction", label: "Attraction", color: "var(--meter-attraction)" },
  { key: "tension", label: "Tension", color: "var(--meter-tension)" },
];

function Meter({ label, value, color }: { label: string; value: number; color: string }) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div className="flex items-center gap-3">
      <span className="t-caption w-24 shrink-0">{label}</span>
      <div className="flex-1 h-2 rounded-full bg-raised overflow-hidden">
        <div style={{ width: `${pct}%`, height: "100%", background: color }} />
      </div>
    </div>
  );
}

export function RelationshipJournal({ characterId }: { characterId: string }) {
  const { character, useReal } = useCharacter(characterId);
  const [personaId, setPersonaId] = useState<string | null>(null);
  useEffect(() => {
    try {
      setPersonaId(localStorage.getItem("hearth-persona"));
    } catch {
      /* ignore */
    }
  }, []);

  const { data: rel } = useQuery({
    queryKey: ["relationship", characterId, personaId],
    queryFn: () => ensureRelationship(getClientBackend(), characterId, personaId as string),
    enabled: useReal && !!personaId,
  });

  const header = (
    <header className="sticky top-0 z-10 flex items-center gap-2 px-gutter h-14 bg-bg/90 backdrop-blur">
      <Link
        href={`/characters/${characterId}`}
        aria-label="Back"
        className="text-muted -ml-2 p-2"
      >
        <ArrowLeftIcon size={22} />
      </Link>
      <div className="t-title">{character ? character.name : "Relationship"}</div>
    </header>
  );

  let body: React.ReactNode;
  if (!useReal) {
    body = (
      <p className="t-body text-muted">
        The relationship journal fills in as you roleplay. Sign in to track it.
      </p>
    );
  } else if (!personaId) {
    body = (
      <p className="t-body text-muted">
        Pick a persona in the Library and start a chat to begin a relationship.
      </p>
    );
  } else if (!rel) {
    body = <p className="t-body text-muted">Loading…</p>;
  } else {
    body = <JournalBody rel={rel} />;
  }

  return (
    <div className="min-h-dvh flex flex-col">
      {header}
      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-2xl px-gutter py-5 flex flex-col gap-6">{body}</div>
      </div>
    </div>
  );
}

function JournalBody({ rel }: { rel: Relationship }) {
  const stage = rel.stages[rel.stageIdx] ?? "—";
  return (
    <>
      <div className="flex flex-col gap-2">
        <Overline>Where things stand</Overline>
        <div className="t-title">{stage}</div>
        {rel.type ? <div className="t-caption text-muted capitalize">{rel.type}</div> : null}
      </div>

      <Card className="p-4 flex flex-col gap-3">
        {METERS.map((m) => (
          <Meter key={m.key} label={m.label} value={rel.values[m.key]} color={m.color} />
        ))}
      </Card>

      <div className="flex flex-col gap-2">
        <Overline>Journal</Overline>
        {rel.events.length === 0 ? (
          <p className="t-caption text-subtle">Nothing yet.</p>
        ) : (
          rel.events.map((e) => (
            <Card key={e.id} className="p-3 flex flex-col gap-0.5">
              <div className="flex items-baseline justify-between gap-2">
                <span className="t-label">{e.title}</span>
                <span className="t-caption text-subtle shrink-0">{timeLabel(e.at)}</span>
              </div>
              {e.why ? <p className="t-caption text-muted">{e.why}</p> : null}
            </Card>
          ))
        )}
      </div>
    </>
  );
}
