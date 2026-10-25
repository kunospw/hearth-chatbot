"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useCharacter } from "@/components/characters/use-character";
import { createPreviewReply } from "@/lib/chat/preview-reply";
import type { Message } from "@/lib/domain/types";
import { createConversation } from "@/lib/repositories/conversations";
import { saveMessage } from "@/lib/repositories/messages";
import { getClientBackend } from "@/lib/supabase/client";
import { ChatView } from "./chat-view";

function Centered({ children }: { children: React.ReactNode }) {
  return <div className="min-h-dvh grid place-items-center p-gutter text-center">{children}</div>;
}

// Entry point for a new chat with a character. Signed in: create a conversation
// (persisting the greeting) and go to /chat/[id]. Preview: a local chat.
export function NewChat({ characterId }: { characterId: string }) {
  const { character, useReal } = useCharacter(characterId);
  const router = useRouter();
  const started = useRef(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!character || !useReal || started.current) return;
    started.current = true;
    void (async () => {
      try {
        const api = getClientBackend();
        const convo = await createConversation(api, { characterId: character.id });
        if (character.greeting) {
          const greet: Message = {
            id: crypto.randomUUID(),
            role: "ai",
            alts: [character.greeting],
            altIndex: 0,
            notes: {},
          };
          await saveMessage(api, greet, convo.id);
        }
        router.replace(`/chat/${convo.id}`);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Couldn’t start the chat.");
      }
    })();
  }, [character, useReal, router]);

  if (!character) {
    return (
      <Centered>
        <div className="flex flex-col gap-4">
          <p className="t-body text-muted">That character isn’t here.</p>
          <Link href="/characters" className="text-ink underline">
            Back to characters
          </Link>
        </div>
      </Centered>
    );
  }

  if (useReal) {
    return (
      <Centered>
        {error ? (
          <div className="flex flex-col gap-4">
            <p className="t-body text-danger">{error}</p>
            <Link href={`/characters/${character.id}`} className="text-ink underline">
              Back
            </Link>
          </div>
        ) : (
          <p className="t-body text-muted">Starting…</p>
        )}
      </Centered>
    );
  }

  // Preview: local chat with a canned reply.
  const greeting: Message[] = character.greeting
    ? [{ id: "greeting", role: "ai", alts: [character.greeting], altIndex: 0, notes: {} }]
    : [];
  return (
    <ChatView
      character={character}
      conversationId="preview"
      initialMessages={greeting}
      reply={createPreviewReply(character.id)}
      persist={false}
    />
  );
}
