"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { useSession } from "@/components/providers/session";
import { CharacterAvatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { ArrowLeftIcon } from "@/components/ui/icons";
import { ChatController, type ChatState, type ConversationStore } from "@/lib/chat/controller";
import { createPreviewReply } from "@/lib/chat/preview-reply";
import { DEFAULT_REPLY_SETTINGS } from "@/lib/chat/types";
import type { ChatMode, Message } from "@/lib/domain/types";
import { listCharacters } from "@/lib/repositories/characters";
import { sampleCharacters } from "@/lib/sample/characters";
import { getClientBackend } from "@/lib/supabase/client";
import { Composer } from "./composer";
import { MessageView } from "./messages";

export function ChatScreen({ characterId }: { characterId: string }) {
  const { configured, session } = useSession();
  const useReal = configured && !!session;

  const { data } = useQuery({
    queryKey: ["characters"],
    queryFn: () => listCharacters(getClientBackend()),
    enabled: useReal,
  });

  const character =
    (useReal ? (data ?? []) : sampleCharacters).find((c) => c.id === characterId) ?? null;

  const [mode, setMode] = useState<ChatMode>("chat");
  const [messages, setMessages] = useState<Message[]>([]);
  const messagesRef = useRef<Message[]>(messages);
  messagesRef.current = messages;

  const store = useMemo<ConversationStore>(
    () => ({
      getMessages: () => messagesRef.current,
      setMessages: (ms) => {
        messagesRef.current = ms;
        setMessages(ms);
      },
    }),
    [],
  );

  // Seed the greeting when the character resolves / changes.
  useEffect(() => {
    if (!character) return;
    const seed: Message[] = character.greeting
      ? [{ id: "greeting", role: "ai", alts: [character.greeting], altIndex: 0, notes: {} }]
      : [];
    messagesRef.current = seed;
    setMessages(seed);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [character?.id]);

  // Until the chats-start + server flow lands, this screen streams through the
  // local preview source. Connecting a Supabase conversation is a config flip:
  // pass the real conversationId and drop `reply`/`persist`.
  const controller = useMemo(() => {
    if (!character) return null;
    return new ChatController({
      api: getClientBackend(),
      conversationId: "preview",
      store,
      modelId: "ember",
      personaId: "me",
      settings: DEFAULT_REPLY_SETTINGS,
      stream: true,
      reply: createPreviewReply(character.id),
      persist: false,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [character?.id]);

  const [gen, setGen] = useState<ChatState | null>(controller?.getState() ?? null);
  useEffect(() => {
    if (!controller) return;
    setGen(controller.getState());
    const unsub = controller.subscribe(setGen);
    return () => {
      unsub();
      controller.dispose();
    };
  }, [controller]);

  const endRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages, gen?.status]);

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

  const generating = gen != null && gen.status !== "idle";

  const handleSend = (text: string) => {
    if (!controller) return;
    if (mode === "story" && !text.trim()) {
      void controller.continueStory();
    } else {
      void controller.send(text);
    }
  };

  return (
    <div className="h-dvh flex flex-col bg-bg">
      <header className="sticky top-0 z-10 flex items-center gap-3 px-gutter h-14 border-b border-outline bg-bg/90 backdrop-blur">
        <Link href="/characters" aria-label="Back" className="text-muted -ml-2 p-2">
          <ArrowLeftIcon size={22} />
        </Link>
        <CharacterAvatar character={character} size={36} radius={10} />
        <div className="t-title truncate flex-1">{character.name}</div>
        <div className="flex rounded-full border border-outline p-0.5 text-[13px]">
          {(["chat", "story"] as ChatMode[]).map((m) => (
            <button
              key={m}
              type="button"
              onClick={() => setMode(m)}
              className={`rounded-full px-3 py-1 capitalize transition-colors ${
                mode === m ? "bg-soft text-ink" : "text-muted"
              }`}
            >
              {m}
            </button>
          ))}
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div
          className={`mx-auto w-full px-gutter py-5 flex flex-col gap-5 ${
            mode === "story" ? "max-w-[640px]" : "max-w-2xl"
          }`}
        >
          {messages.map((m) => (
            <MessageView
              key={m.id}
              message={m}
              story={mode === "story"}
              streaming={generating && gen?.activeId === m.id}
              stopped={controller?.wasStopped(m.id) ?? false}
            />
          ))}

          {gen?.error ? (
            <div className="rounded-card border border-outline bg-surface p-4 flex flex-col gap-2">
              <p className="t-body text-danger">
                {gen.error instanceof Error ? gen.error.message : "Something went wrong."}
              </p>
              <Button
                variant="ghost"
                className="self-start"
                onClick={() => void controller?.retry()}
              >
                Try again
              </Button>
            </div>
          ) : null}

          <div ref={endRef} />
        </div>
      </div>

      <Composer
        generating={generating}
        story={mode === "story"}
        onSend={handleSend}
        onStop={() => controller?.stop()}
      />
    </div>
  );
}
