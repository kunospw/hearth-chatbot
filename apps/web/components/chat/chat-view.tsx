"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  CHAT_LINE_HEIGHTS,
  STORY_LINE_HEIGHTS,
  usePrefs,
} from "@/components/providers/prefs";
import { CharacterAvatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { ArrowLeftIcon } from "@/components/ui/icons";
import { ChatController, type ChatState, type ConversationStore } from "@/lib/chat/controller";
import type { ReplyFn } from "@/lib/chat/reply";
import type { Character, ChatMode, Message } from "@/lib/domain/types";
import { getClientBackend } from "@/lib/supabase/client";
import { Composer } from "./composer";
import { MessageView } from "./messages";

// The chat/story experience over a resolved conversation. Wrappers supply the
// character, conversation id, seed messages and reply source (server vs
// preview). SPEC: AI replies are full-width prose; only user turns are bubbles.

export interface ChatViewProps {
  character: Character;
  conversationId: string;
  initialMessages: Message[];
  initialMode?: ChatMode;
  /** Undefined = the server's chat_turn; a function = preview/local. */
  reply?: ReplyFn;
  persist: boolean;
  personaId?: string;
  modelId?: string;
}

export function ChatView({
  character,
  conversationId,
  initialMessages,
  initialMode = "chat",
  reply,
  persist,
  personaId = "me",
}: ChatViewProps) {
  const { prefs } = usePrefs();
  const [mode, setMode] = useState<ChatMode>(initialMode);
  const [messages, setMessages] = useState<Message[]>(initialMessages);
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

  // Reseed when the conversation changes.
  useEffect(() => {
    messagesRef.current = initialMessages;
    setMessages(initialMessages);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversationId]);

  const controller = useMemo(
    () =>
      new ChatController({
        api: getClientBackend(),
        conversationId,
        store,
        modelId: prefs.modelId,
        personaId,
        settings: prefs.ai,
        stream: prefs.reading.animate,
        reply,
        persist,
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [conversationId],
  );

  // Keep the controller's model / settings / animate in sync with prefs.
  useEffect(() => {
    controller.configure({
      modelId: prefs.modelId,
      settings: prefs.ai,
      stream: prefs.reading.animate,
    });
  }, [controller, prefs.modelId, prefs.ai, prefs.reading.animate]);

  const [gen, setGen] = useState<ChatState>(controller.getState());
  useEffect(() => {
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
  }, [messages, gen.status]);

  const generating = gen.status !== "idle";

  const lineIndex = prefs.reading.lineIndex;
  const textStyle =
    mode === "story"
      ? { fontSize: prefs.reading.storySize, lineHeight: STORY_LINE_HEIGHTS[lineIndex] }
      : { fontSize: prefs.reading.chatSize, lineHeight: CHAT_LINE_HEIGHTS[lineIndex] };

  const handleSend = (text: string) => {
    if (mode === "story" && !text.trim()) void controller.continueStory();
    else void controller.send(text);
  };

  return (
    <div className="h-dvh flex flex-col bg-bg">
      <header className="sticky top-0 z-10 flex items-center gap-3 px-gutter h-14 border-b border-outline bg-bg/90 backdrop-blur">
        <Link
          href={`/characters/${character.id}`}
          aria-label="Back"
          className="text-muted -ml-2 p-2"
        >
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
              streaming={generating && gen.activeId === m.id}
              stopped={controller.wasStopped(m.id)}
              textStyle={textStyle}
            />
          ))}

          {gen.error ? (
            <div className="rounded-card border border-outline bg-surface p-4 flex flex-col gap-2">
              <p className="t-body text-danger">
                {gen.error instanceof Error ? gen.error.message : "Something went wrong."}
              </p>
              <Button variant="ghost" className="self-start" onClick={() => void controller.retry()}>
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
        onStop={() => controller.stop()}
      />
    </div>
  );
}
