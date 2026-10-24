"use client";

import Link from "next/link";
import { useState } from "react";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { ArrowLeftIcon } from "@/components/ui/icons";
import { Overline } from "@/components/ui/overline";
import { useCharacter } from "./use-character";

function Section({ title, body }: { title: string; body: string }) {
  if (!body.trim()) return null;
  return (
    <div className="flex flex-col gap-1.5">
      <Overline>{title}</Overline>
      <p className="t-body text-muted whitespace-pre-wrap">{body}</p>
    </div>
  );
}

export function CharacterDetail({ characterId }: { characterId: string }) {
  const { character } = useCharacter(characterId);
  const [showMore, setShowMore] = useState(false);

  if (!character) {
    return (
      <div className="min-h-dvh grid place-items-center p-gutter text-center">
        <div className="flex flex-col gap-4">
          <p className="t-body text-muted">That character isn’t here.</p>
          <Link href="/characters" className="text-ink underline">
            Back to characters
          </Link>
        </div>
      </div>
    );
  }

  const c = character;
  const first = c.first || c.name;

  return (
    <div className="min-h-dvh flex flex-col">
      <header className="sticky top-0 z-10 flex items-center gap-2 px-gutter h-14 bg-bg/90 backdrop-blur">
        <Link href="/characters" aria-label="Back" className="text-muted -ml-2 p-2">
          <ArrowLeftIcon size={22} />
        </Link>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-2xl px-gutter pb-28 flex flex-col gap-6">
          <div className="flex flex-col items-center text-center gap-3 pt-2">
            <Avatar
              tile={c.tile}
              ink={c.ink}
              initial={c.initial || first.slice(0, 1)}
              src={c.portraitUrl}
              size={120}
              radius={24}
            />
            <h1 className="t-display">{c.name}</h1>
            {c.tags.length ? (
              <div className="flex flex-wrap justify-center gap-2">
                {c.tags.map((t) => (
                  <span
                    key={t}
                    className="rounded-full bg-raised px-2.5 py-1 t-caption text-muted"
                  >
                    {t}
                  </span>
                ))}
              </div>
            ) : null}
            {c.short ? <p className="t-body text-muted max-w-prose">{c.short}</p> : null}
          </div>

          {c.intro ? (
            <div className="flex flex-col gap-1.5">
              <Overline>Introduction</Overline>
              <p
                className={`t-body text-muted whitespace-pre-wrap ${showMore ? "" : "line-clamp-3"}`}
              >
                {c.intro}
              </p>
            </div>
          ) : null}

          {showMore ? (
            <>
              <Section title={`More about ${first}`} body={c.personality} />
              <Section title="Speaking style" body={c.speaking} />
              <Section title="Scenario" body={c.scenario} />
              <Section title="Example dialogue" body={c.exampleDialogue} />
            </>
          ) : null}

          {c.personality || c.speaking || c.scenario || c.exampleDialogue || c.intro ? (
            <button
              type="button"
              onClick={() => setShowMore((v) => !v)}
              className="self-start text-ink t-body"
            >
              {showMore ? "Show less" : `More about ${first}`}
            </button>
          ) : null}
        </div>
      </div>

      <div className="sticky bottom-0 border-t border-outline bg-bg px-gutter py-3">
        <div className="mx-auto max-w-2xl flex gap-3">
          <Link href={`/characters/${c.id}/edit`} className="flex-1">
            <Button variant="ghost" className="w-full">
              Edit
            </Button>
          </Link>
          <Link href={`/chat/c/${c.id}`} className="flex-1">
            <Button className="w-full">Start new chat</Button>
          </Link>
        </div>
      </div>
    </div>
  );
}
