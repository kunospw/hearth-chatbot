"use client";

import type { CSSProperties } from "react";
import { RichRoleplayText } from "@/components/ui/rich-roleplay-text";
import { Overline } from "@/components/ui/overline";
import type { Message } from "@/lib/domain/types";

// AI replies are full-width prose (not bubbles); only user messages are bubbles.
// In story mode the user's turns are small italic "YOU" blocks. SPEC.

function ThinkingDots() {
  return (
    <div className="flex gap-1.5 py-2" aria-label="Thinking">
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="h-2 w-2 rounded-full bg-subtle animate-pulse"
          style={{ animationDelay: `${i * 150}ms` }}
        />
      ))}
    </div>
  );
}

export function AiMessage({
  text,
  streaming,
  stopped,
  textStyle,
}: {
  text: string;
  streaming: boolean;
  stopped: boolean;
  textStyle?: CSSProperties;
}) {
  const empty = text.trim().length === 0;
  return (
    <div className="w-full">
      {empty && streaming ? (
        <ThinkingDots />
      ) : (
        <RichRoleplayText text={text} className="t-story" style={textStyle} />
      )}
      {stopped ? <p className="t-caption text-subtle mt-1">Stopped</p> : null}
    </div>
  );
}

export function UserBubble({ text, textStyle }: { text: string; textStyle?: CSSProperties }) {
  return (
    <div className="flex justify-end">
      <div
        className="max-w-[85%] rounded-card px-4 py-2.5 t-chat"
        style={{ background: "var(--primary-soft)", ...textStyle }}
      >
        {text}
      </div>
    </div>
  );
}

export function StoryUserBlock({ text, textStyle }: { text: string; textStyle?: CSSProperties }) {
  return (
    <div className="my-2">
      <Overline>You</Overline>
      <p className="t-story italic" style={{ color: "var(--text-muted)", ...textStyle }}>
        {text}
      </p>
    </div>
  );
}

export function MessageView({
  message,
  story,
  streaming,
  stopped,
  textStyle,
}: {
  message: Message;
  story: boolean;
  streaming: boolean;
  stopped: boolean;
  textStyle?: CSSProperties;
}) {
  const text = message.alts[message.altIndex] ?? message.alts[0] ?? "";
  if (message.role === "user") {
    return story ? (
      <StoryUserBlock text={text} textStyle={textStyle} />
    ) : (
      <UserBubble text={text} textStyle={textStyle} />
    );
  }
  return <AiMessage text={text} streaming={streaming} stopped={stopped} textStyle={textStyle} />;
}
