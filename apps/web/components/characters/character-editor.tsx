"use client";

import { useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { ArrowLeftIcon } from "@/components/ui/icons";
import { Overline } from "@/components/ui/overline";
import { hexToArgb } from "@/lib/backend/color";
import type { Character } from "@/lib/domain/types";
import { saveCharacter } from "@/lib/repositories/characters";
import { getClientBackend } from "@/lib/supabase/client";
import { useCharacter } from "./use-character";

const SWATCHES = [
  { tile: "#3B1F27", ink: "#E9A0AE" },
  { tile: "#1F2E3B", ink: "#BFD9D6" },
  { tile: "#2E2A1F", ink: "#F2CF9A" },
  { tile: "#2A1F2E", ink: "#D8B4E2" },
  { tile: "#1F2E27", ink: "#A8D8B9" },
  { tile: "#2E1F1F", ink: "#EF8A78" },
];

function Field({
  label,
  value,
  onChange,
  textarea,
  placeholder,
  required,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  textarea?: boolean;
  placeholder?: string;
  required?: boolean;
}) {
  const cls =
    "w-full bg-surface border border-outline rounded-field px-3 py-2.5 text-[15px] text-text placeholder:text-subtle outline-none focus:border-ink";
  return (
    <label className="flex flex-col gap-1.5">
      <Overline>
        {label}
        {required ? " *" : ""}
      </Overline>
      {textarea ? (
        <textarea
          rows={3}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className={`${cls} resize-y min-h-20`}
        />
      ) : (
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className={`${cls} min-h-12`}
        />
      )}
    </label>
  );
}

export function CharacterEditor({ characterId }: { characterId?: string }) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { character: existing, useReal } = useCharacter(characterId ?? "");

  const initialSwatch = useMemo(() => {
    if (!existing) return 0;
    const i = SWATCHES.findIndex((s) => hexToArgb(s.tile) === existing.tile);
    return i >= 0 ? i : 0;
  }, [existing]);

  const [name, setName] = useState(existing?.name ?? "");
  const [short, setShort] = useState(existing?.short ?? "");
  const [greeting, setGreeting] = useState(existing?.greeting ?? "");
  const [intro, setIntro] = useState(existing?.intro ?? "");
  const [personality, setPersonality] = useState(existing?.personality ?? "");
  const [speaking, setSpeaking] = useState(existing?.speaking ?? "");
  const [exampleDialogue, setExampleDialogue] = useState(existing?.exampleDialogue ?? "");
  const [rules, setRules] = useState(existing?.rules ?? "");
  const [scenario, setScenario] = useState(existing?.scenario ?? "");
  const [tags, setTags] = useState((existing?.tags ?? []).join(", "));
  const [swatch, setSwatch] = useState(initialSwatch);
  const [showMore, setShowMore] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const sw = SWATCHES[swatch];
  const first = (name.trim().split(/\s+/)[0] || "").slice(0, 1).toUpperCase() || "?";

  async function save(startChat: boolean) {
    const trimmed = name.trim();
    if (!trimmed) {
      setError("Name is required.");
      return;
    }
    const id = existing?.id ?? crypto.randomUUID();
    const firstName = trimmed.split(/\s+/)[0];
    const character: Character = {
      id,
      name: trimmed,
      first: firstName,
      initial: firstName.slice(0, 1).toUpperCase(),
      tile: hexToArgb(sw.tile),
      ink: hexToArgb(sw.ink),
      short,
      universeId: existing?.universeId ?? null,
      portraitAsset: null,
      portraitUrl: existing?.portraitUrl ?? null,
      tags: tags.split(",").map((t) => t.trim()).filter(Boolean),
      intro,
      personality,
      speaking,
      greeting,
      exampleDialogue,
      rules,
      relationships: existing?.relationships ?? "",
      scenario,
      archived: existing?.archived ?? false,
    };

    if (!useReal) {
      setError("Connect Supabase and sign in to save characters.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await saveCharacter(getClientBackend(), character);
      await queryClient.invalidateQueries({ queryKey: ["characters"] });
      router.push(startChat ? `/chat/c/${id}` : `/characters/${id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Couldn’t save.");
    } finally {
      setBusy(false);
    }
  }

  const backHref = existing ? `/characters/${existing.id}` : "/characters";

  return (
    <div className="min-h-dvh flex flex-col">
      <header className="sticky top-0 z-10 flex items-center gap-2 px-gutter h-14 bg-bg/90 backdrop-blur">
        <Link href={backHref} aria-label="Back" className="text-muted -ml-2 p-2">
          <ArrowLeftIcon size={22} />
        </Link>
        <div className="t-title">{existing ? "Edit character" : "New character"}</div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-2xl px-gutter pb-28 flex flex-col gap-5">
          <div className="flex items-center gap-4 pt-2">
            <Avatar tile={hexToArgb(sw.tile)} ink={hexToArgb(sw.ink)} initial={first} size={72} radius={16} />
            <div className="flex flex-wrap gap-2">
              {SWATCHES.map((s, i) => (
                <button
                  key={s.tile}
                  type="button"
                  aria-label={`Colour ${i + 1}`}
                  onClick={() => setSwatch(i)}
                  className={`h-8 w-8 rounded-full border-2 transition-colors ${
                    swatch === i ? "border-ink" : "border-transparent"
                  }`}
                  style={{ background: s.tile }}
                />
              ))}
            </div>
          </div>

          <Field label="Name" value={name} onChange={setName} required placeholder="e.g. Captain Morrow" />
          <Field label="Short description" value={short} onChange={setShort} placeholder="One line shown on the card" />
          <Field
            label="Greeting"
            value={greeting}
            onChange={setGreeting}
            textarea
            placeholder={'The first thing they say. Use *actions* and "dialogue".'}
          />

          <button
            type="button"
            onClick={() => setShowMore((v) => !v)}
            className="self-start text-ink t-body"
          >
            {showMore ? "Fewer details" : "More details"}
          </button>

          {showMore ? (
            <>
              <Field label="Introduction" value={intro} onChange={setIntro} textarea />
              <Field label="Personality" value={personality} onChange={setPersonality} textarea />
              <Field label="Speaking style" value={speaking} onChange={setSpeaking} textarea />
              <Field label="Example dialogue" value={exampleDialogue} onChange={setExampleDialogue} textarea />
              <Field label="Scenario" value={scenario} onChange={setScenario} textarea />
              <Field label="Rules" value={rules} onChange={setRules} textarea />
              <Field label="Tags" value={tags} onChange={setTags} placeholder="Comma separated" />
            </>
          ) : null}

          {error ? <p className="t-caption text-danger">{error}</p> : null}
        </div>
      </div>

      <div className="sticky bottom-0 border-t border-outline bg-bg px-gutter py-3">
        <div className="mx-auto max-w-2xl flex gap-3">
          <Button variant="ghost" className="flex-1" disabled={busy} onClick={() => save(false)}>
            Save
          </Button>
          <Button className="flex-1" disabled={busy} onClick={() => save(true)}>
            {busy ? "Saving…" : "Save & start chat"}
          </Button>
        </div>
      </div>
    </div>
  );
}
