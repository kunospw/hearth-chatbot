"use client";

import { createContext, useContext, useEffect, useState } from "react";
import type { ReplySettings } from "@/lib/chat/types";

// AI + reading preferences, persisted in localStorage. Feeds the chat
// controller (ReplySettings + animate) and the reading sizes. Mirrors
// AiPrefs / reading_prefs in the Flutter app.

export interface ReadingPrefs {
  chatSize: number; // 14–22
  storySize: number; // 15–26
  lineIndex: number; // 0 Compact, 1 Comfortable, 2 Roomy
  animate: boolean;
}

export const CHAT_LINE_HEIGHTS = [1.5, 1.62, 1.8];
export const STORY_LINE_HEIGHTS = [1.58, 1.72, 1.9];

interface Prefs {
  modelId: string;
  ai: ReplySettings;
  reading: ReadingPrefs;
}

const DEFAULT: Prefs = {
  modelId: "ember",
  ai: {
    length: "medium",
    style: "descriptive",
    temperature: 0.9,
    maxTokens: 600,
    repetitionPenalty: 1.1,
    contextDepth: 40,
  },
  reading: { chatSize: 16, storySize: 19, lineIndex: 1, animate: true },
};

interface PrefsContextValue {
  prefs: Prefs;
  setModelId: (id: string) => void;
  setAi: (patch: Partial<ReplySettings>) => void;
  setReading: (patch: Partial<ReadingPrefs>) => void;
}

const PrefsContext = createContext<PrefsContextValue>({
  prefs: DEFAULT,
  setModelId: () => {},
  setAi: () => {},
  setReading: () => {},
});

const KEY = "hearth-prefs";

export function PrefsProvider({ children }: { children: React.ReactNode }) {
  const [prefs, setPrefs] = useState<Prefs>(DEFAULT);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<Prefs>;
        setPrefs({
          modelId: parsed.modelId ?? DEFAULT.modelId,
          ai: { ...DEFAULT.ai, ...parsed.ai },
          reading: { ...DEFAULT.reading, ...parsed.reading },
        });
      }
    } catch {
      /* ignore */
    }
  }, []);

  const persist = (next: Prefs) => {
    setPrefs(next);
    try {
      localStorage.setItem(KEY, JSON.stringify(next));
    } catch {
      /* ignore */
    }
  };

  return (
    <PrefsContext.Provider
      value={{
        prefs,
        setModelId: (id) => persist({ ...prefs, modelId: id }),
        setAi: (patch) => persist({ ...prefs, ai: { ...prefs.ai, ...patch } }),
        setReading: (patch) => persist({ ...prefs, reading: { ...prefs.reading, ...patch } }),
      }}
    >
      {children}
    </PrefsContext.Provider>
  );
}

export const usePrefs = () => useContext(PrefsContext);
