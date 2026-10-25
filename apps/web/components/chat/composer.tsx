"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { SendIcon, StopIcon } from "@/components/ui/icons";

// Grows 1–5 lines. Enter inserts a newline; Ctrl/Cmd+Enter sends. In story mode
// an empty send means "Continue". Send becomes Stop while generating. SPEC.

interface ComposerProps {
  generating: boolean;
  story?: boolean;
  onSend: (text: string) => void;
  onStop: () => void;
}

export function Composer({ generating, story = false, onSend, onStop }: ComposerProps) {
  const [text, setText] = useState("");
  const ref = useRef<HTMLTextAreaElement>(null);

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = "auto";
    const lineHeight = 24;
    el.style.height = `${Math.min(el.scrollHeight, lineHeight * 5 + 20)}px`;
  }, [text]);

  const canSend = story || text.trim().length > 0;

  const send = () => {
    if (generating || !canSend) return;
    onSend(text);
    setText("");
  };

  return (
    <div className="flex items-end gap-2 border-t border-outline bg-bg px-gutter py-3">
      <textarea
        ref={ref}
        rows={1}
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
            e.preventDefault();
            send();
          }
        }}
        placeholder={story ? "Write, or send empty to continue…" : "Message…"}
        className="flex-1 resize-none bg-surface border border-outline rounded-field px-3 py-2.5 text-[16px] leading-6 text-text placeholder:text-subtle outline-none focus:border-ink"
      />
      <button
        type="button"
        aria-label={generating ? "Stop" : "Send"}
        onClick={generating ? onStop : send}
        disabled={!generating && !canSend}
        className="shrink-0 grid place-items-center h-12 w-12 rounded-button bg-primary text-on-primary disabled:opacity-40 disabled:pointer-events-none hover:bg-primary-pressed transition-colors"
      >
        {generating ? <StopIcon size={20} /> : <SendIcon size={20} />}
      </button>
    </div>
  );
}
