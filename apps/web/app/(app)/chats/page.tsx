"use client";

import Link from "next/link";
import { useCharacters } from "@/components/characters/use-character";
import { useConversations } from "@/components/chats/use-conversations";
import { CharacterAvatar } from "@/components/ui/avatar";
import { Overline } from "@/components/ui/overline";
import type { Character, Conversation } from "@/lib/domain/types";
import { timeLabel } from "@/lib/util/time";

function Row({ convo, character }: { convo: Conversation; character?: Character }) {
  const title = character?.name ?? "Chat";
  const subtitle = convo.title && convo.title !== "New chat" ? convo.title : null;
  return (
    <Link
      href={`/chat/${convo.id}`}
      className="flex items-center gap-3 rounded-card px-2 py-2.5 hover:bg-surface transition-colors"
    >
      {character ? (
        <CharacterAvatar character={character} size={44} radius={12} />
      ) : (
        <div className="h-11 w-11 rounded-field bg-raised" />
      )}
      <div className="min-w-0 flex-1">
        <div className="t-label truncate">{title}</div>
        {subtitle ? <div className="t-caption truncate">{subtitle}</div> : null}
      </div>
      <div className="t-caption text-subtle shrink-0">{timeLabel(convo.updatedAt)}</div>
    </Link>
  );
}

export default function ChatsPage() {
  const { conversations, useReal } = useConversations();
  const { characters } = useCharacters();
  const byId = new Map(characters.map((c) => [c.id, c]));

  const active = conversations.filter((c) => !c.archived);
  const pinned = active.filter((c) => c.pinned);
  const recent = active.filter((c) => !c.pinned);

  if (active.length === 0) {
    return (
      <div className="flex flex-col gap-4">
        <Overline>Chats</Overline>
        <h1 className="t-display">Your chats</h1>
        <p className="t-body text-muted">
          {useReal
            ? "No chats yet. Pick a character to start one."
            : "Sign in to keep chats. In preview, open a character to try a conversation."}
        </p>
        <Link href="/characters" className="text-ink underline">
          Browse characters
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-1">
        <Overline>Chats</Overline>
        <h1 className="t-display">Your chats</h1>
      </header>

      {pinned.length ? (
        <section className="flex flex-col gap-1">
          <Overline>Pinned</Overline>
          {pinned.map((c) => (
            <Row key={c.id} convo={c} character={byId.get(c.characterId)} />
          ))}
        </section>
      ) : null}

      <section className="flex flex-col gap-1">
        {pinned.length ? <Overline>Recent</Overline> : null}
        {recent.map((c) => (
          <Row key={c.id} convo={c} character={byId.get(c.characterId)} />
        ))}
      </section>
    </div>
  );
}
