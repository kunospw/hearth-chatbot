"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";
import { usePrefs } from "@/components/providers/prefs";
import { useSession } from "@/components/providers/session";
import { ArrowLeftIcon } from "@/components/ui/icons";
import { Overline } from "@/components/ui/overline";
import { freeRepliesLeft, listModels, listTodayUsage } from "@/lib/repositories/models";
import { sampleModels } from "@/lib/sample/models";
import { getClientBackend } from "@/lib/supabase/client";

const LINE = ["Compact", "Comfortable", "Roomy"];
const selectCls =
  "bg-surface border border-outline rounded-field px-3 min-h-11 text-[15px] text-text outline-none focus:border-ink";

export default function AiSettingsPage() {
  const { configured, session } = useSession();
  const useReal = configured && !!session;
  const { prefs, setModelId, setAi, setReading } = usePrefs();
  const [advanced, setAdvanced] = useState(false);

  const { data: models } = useQuery({
    queryKey: ["models"],
    queryFn: () => listModels(getClientBackend()),
    enabled: useReal,
  });
  const { data: usage } = useQuery({
    queryKey: ["model-usage"],
    queryFn: () => listTodayUsage(getClientBackend()),
    enabled: useReal,
  });
  const list = useReal ? (models ?? []) : sampleModels;

  return (
    <div className="flex flex-col gap-8">
      <header className="flex items-center gap-2 -ml-2">
        <Link href="/settings" aria-label="Back" className="text-muted p-2">
          <ArrowLeftIcon size={22} />
        </Link>
        <h1 className="t-display">AI settings</h1>
      </header>

      <section className="flex flex-col gap-3">
        <Overline>Model</Overline>
        {list.map((m) => {
          const left = useReal ? freeRepliesLeft(m, usage ?? []) : m.dailyFreeReplies;
          const status = m.busy
            ? "Busy"
            : left == null
              ? "Unlimited"
              : `${left} free left today`;
          return (
            <label
              key={m.id}
              className="flex items-center gap-3 rounded-field border border-outline bg-surface px-3 py-3 cursor-pointer"
            >
              <input
                type="radio"
                name="model"
                checked={prefs.modelId === m.id}
                onChange={() => setModelId(m.id)}
                disabled={m.busy}
                className="accent-[var(--primary)]"
              />
              <div className="min-w-0 flex-1">
                <div className="t-label">{m.name}</div>
                <div className="t-caption text-muted truncate">{m.description}</div>
              </div>
              <span className="t-caption text-subtle shrink-0">{status}</span>
            </label>
          );
        })}
      </section>

      <section className="flex flex-col gap-4">
        <Overline>Replies</Overline>
        <label className="flex items-center justify-between gap-3">
          <span className="t-body">Length</span>
          <select
            value={prefs.ai.length}
            onChange={(e) => setAi({ length: e.target.value })}
            className={selectCls}
          >
            <option value="short">Short</option>
            <option value="medium">Medium</option>
            <option value="long">Long</option>
          </select>
        </label>
        <label className="flex items-center justify-between gap-3">
          <span className="t-body">Writing style</span>
          <select
            value={prefs.ai.style}
            onChange={(e) => setAi({ style: e.target.value })}
            className={selectCls}
          >
            <option value="descriptive">Descriptive</option>
            <option value="concise">Concise</option>
            <option value="poetic">Poetic</option>
          </select>
        </label>
        <label className="flex flex-col gap-1.5">
          <div className="flex justify-between">
            <span className="t-body">Creativity</span>
            <span className="t-caption text-subtle">{prefs.ai.temperature.toFixed(2)}</span>
          </div>
          <input
            type="range"
            min={0.5}
            max={1.3}
            step={0.05}
            value={prefs.ai.temperature}
            onChange={(e) => setAi({ temperature: Number(e.target.value) })}
            className="accent-[var(--primary)]"
          />
        </label>
      </section>

      <section className="flex flex-col gap-4">
        <Overline>Reading</Overline>
        <label className="flex flex-col gap-1.5">
          <div className="flex justify-between">
            <span className="t-body">Chat text size</span>
            <span className="t-caption text-subtle">{prefs.reading.chatSize}</span>
          </div>
          <input
            type="range"
            min={14}
            max={22}
            step={1}
            value={prefs.reading.chatSize}
            onChange={(e) => setReading({ chatSize: Number(e.target.value) })}
            className="accent-[var(--primary)]"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <div className="flex justify-between">
            <span className="t-body">Story text size</span>
            <span className="t-caption text-subtle">{prefs.reading.storySize}</span>
          </div>
          <input
            type="range"
            min={15}
            max={26}
            step={1}
            value={prefs.reading.storySize}
            onChange={(e) => setReading({ storySize: Number(e.target.value) })}
            className="accent-[var(--primary)]"
          />
        </label>
        <div className="flex items-center justify-between gap-3">
          <span className="t-body">Line spacing</span>
          <div className="flex rounded-full border border-outline p-0.5 text-[13px]">
            {LINE.map((l, i) => (
              <button
                key={l}
                type="button"
                onClick={() => setReading({ lineIndex: i })}
                className={`rounded-full px-3 py-1 ${
                  prefs.reading.lineIndex === i ? "bg-soft text-ink" : "text-muted"
                }`}
              >
                {l}
              </button>
            ))}
          </div>
        </div>
        <label className="flex items-center justify-between gap-3">
          <span className="t-body">Animate replies</span>
          <input
            type="checkbox"
            checked={prefs.reading.animate}
            onChange={(e) => setReading({ animate: e.target.checked })}
            className="h-5 w-5 accent-[var(--primary)]"
          />
        </label>
      </section>

      <section className="flex flex-col gap-3">
        <button
          type="button"
          onClick={() => setAdvanced((v) => !v)}
          className="self-start text-ink t-body"
        >
          {advanced ? "Hide advanced" : "Advanced"}
        </button>
        {advanced ? (
          <div className="flex flex-col gap-4">
            <label className="flex items-center justify-between gap-3">
              <span className="t-body">Max tokens</span>
              <input
                type="number"
                value={prefs.ai.maxTokens}
                onChange={(e) => setAi({ maxTokens: Number(e.target.value) })}
                className={`${selectCls} w-28`}
              />
            </label>
            <label className="flex items-center justify-between gap-3">
              <span className="t-body">Context depth</span>
              <input
                type="number"
                value={prefs.ai.contextDepth}
                onChange={(e) => setAi({ contextDepth: Number(e.target.value) })}
                className={`${selectCls} w-28`}
              />
            </label>
            <label className="flex items-center justify-between gap-3">
              <span className="t-body">Repetition penalty</span>
              <input
                type="number"
                step={0.05}
                value={prefs.ai.repetitionPenalty}
                onChange={(e) => setAi({ repetitionPenalty: Number(e.target.value) })}
                className={`${selectCls} w-28`}
              />
            </label>
          </div>
        ) : null}
      </section>
    </div>
  );
}
