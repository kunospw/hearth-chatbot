"use client";

import { useState } from "react";
import { Overline } from "@/components/ui/overline";
import { MemoriesView } from "./memories-view";
import { PersonasView } from "./personas-view";
import { UniversesView } from "./universes-view";

type Tab = "universes" | "memories" | "personas";
const TABS: { key: Tab; label: string }[] = [
  { key: "universes", label: "Universes" },
  { key: "memories", label: "Memories" },
  { key: "personas", label: "Personas" },
];

export function LibraryTabs() {
  const [tab, setTab] = useState<Tab>("universes");
  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-col gap-1">
        <Overline>Library</Overline>
        <h1 className="t-display">Library</h1>
      </header>

      <div className="flex rounded-full border border-outline p-0.5 self-start text-[14px]">
        {TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            onClick={() => setTab(t.key)}
            className={`rounded-full px-4 py-1.5 transition-colors ${
              tab === t.key ? "bg-soft text-ink" : "text-muted"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === "universes" ? (
        <UniversesView />
      ) : tab === "memories" ? (
        <MemoriesView />
      ) : (
        <PersonasView />
      )}
    </div>
  );
}
