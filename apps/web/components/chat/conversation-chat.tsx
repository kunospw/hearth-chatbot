"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useCharacters } from "@/components/characters/use-character";
import { getConversation } from "@/lib/repositories/conversations";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { getClientBackend } from "@/lib/supabase/client";
import { ChatView } from "./chat-view";

function Centered({ children }: { children: React.ReactNode }) {
  return <div className="min-h-dvh grid place-items-center p-gutter text-center">{children}</div>;
}

// An existing, persisted conversation. Streams through the server's chat_turn.
export function ConversationChat({ conversationId }: { conversationId: string }) {
  const { characters } = useCharacters();
  const { data: convo, isLoading } = useQuery({
    queryKey: ["conversation", conversationId],
    queryFn: () => getConversation(getClientBackend(), conversationId),
    enabled: hasSupabaseEnv,
  });

  if (isLoading) {
    return (
      <Centered>
        <p className="t-body text-muted">Loading…</p>
      </Centered>
    );
  }

  const character = convo ? characters.find((c) => c.id === convo.characterId) : undefined;
  if (!convo || !character) {
    return (
      <Centered>
        <div className="flex flex-col gap-4">
          <p className="t-body text-muted">This chat isn’t here.</p>
          <Link href="/chats" className="text-ink underline">
            Back to chats
          </Link>
        </div>
      </Centered>
    );
  }

  return (
    <ChatView
      character={character}
      conversationId={convo.id}
      initialMessages={convo.messages}
      initialMode={convo.mode}
      personaId={convo.personaId ?? "me"}
      persist
    />
  );
}
