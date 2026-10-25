"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useSession } from "@/components/providers/session";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Field } from "@/components/ui/field";
import { PlusIcon } from "@/components/ui/icons";
import { Modal } from "@/components/ui/modal";
import { Overline } from "@/components/ui/overline";
import type { Memory, MemoryCategory } from "@/lib/domain/types";
import {
  deleteMemory,
  listMemories,
  listUniverses,
  saveMemory,
} from "@/lib/repositories/library";
import { getClientBackend } from "@/lib/supabase/client";
import { PreviewNotice } from "./preview-notice";

const CATS: { key: MemoryCategory; label: string }[] = [
  { key: "important", label: "Important" },
  { key: "facts", label: "Story Facts" },
  { key: "relationships", label: "Character Relationships" },
  { key: "world", label: "World Details" },
];

const selectCls =
  "w-full bg-bg border border-outline rounded-field px-3 min-h-12 text-[15px] text-text outline-none focus:border-ink";

export function MemoriesView() {
  const { configured, session } = useSession();
  const useReal = configured && !!session;
  const qc = useQueryClient();

  const { data: memories } = useQuery({
    queryKey: ["memories"],
    queryFn: () => listMemories(getClientBackend()),
    enabled: useReal,
  });
  const { data: universes } = useQuery({
    queryKey: ["universes"],
    queryFn: () => listUniverses(getClientBackend()),
    enabled: useReal,
  });
  const list = memories ?? [];
  const unis = universes ?? [];

  const [filter, setFilter] = useState("all");
  const [open, setOpen] = useState(false);
  const [uni, setUni] = useState("");
  const [cat, setCat] = useState<MemoryCategory>("facts");
  const [text, setText] = useState("");

  const invalidate = () => void qc.invalidateQueries({ queryKey: ["memories"] });

  const save = useMutation({
    mutationFn: async () => {
      const m: Memory = {
        id: crypto.randomUUID(),
        universeId: uni,
        category: cat,
        text,
        pinned: false,
      };
      await saveMemory(getClientBackend(), m);
    },
    onSuccess: () => {
      invalidate();
      setOpen(false);
      setText("");
    },
  });
  const del = useMutation({
    mutationFn: (id: string) => deleteMemory(getClientBackend(), id),
    onSuccess: invalidate,
  });
  const pin = useMutation({
    mutationFn: (m: Memory) => saveMemory(getClientBackend(), { ...m, pinned: !m.pinned }),
    onSuccess: invalidate,
  });

  if (!useReal) return <PreviewNotice kind="memories" />;

  const filtered = filter === "all" ? list : list.filter((m) => m.universeId === filter);

  return (
    <div className="flex flex-col gap-4">
      {unis.length ? (
        <select value={filter} onChange={(e) => setFilter(e.target.value)} className={selectCls}>
          <option value="all">All universes</option>
          {unis.map((u) => (
            <option key={u.id} value={u.id}>
              {u.name}
            </option>
          ))}
        </select>
      ) : null}

      {CATS.map((c) => {
        const items = filtered.filter((m) => m.category === c.key);
        if (!items.length) return null;
        return (
          <section key={c.key} className="flex flex-col gap-2">
            <Overline>{c.label}</Overline>
            {items.map((m) => (
              <Card key={m.id} className="p-3 flex items-start gap-3">
                <p className="t-body text-muted flex-1 whitespace-pre-wrap">{m.text}</p>
                <button
                  type="button"
                  className="t-caption text-ink shrink-0"
                  onClick={() => pin.mutate(m)}
                >
                  {m.pinned ? "Unpin" : "Pin"}
                </button>
                <button
                  type="button"
                  className="t-caption text-danger shrink-0"
                  onClick={() => del.mutate(m.id)}
                >
                  Delete
                </button>
              </Card>
            ))}
          </section>
        );
      })}

      {filtered.length === 0 ? <p className="t-body text-muted">No memories yet.</p> : null}

      <Button
        variant="ghost"
        className="self-start"
        disabled={unis.length === 0}
        onClick={() => {
          setUni(unis[0]?.id ?? "");
          setOpen(true);
        }}
      >
        <PlusIcon size={18} /> Add memory
      </Button>
      {unis.length === 0 ? (
        <p className="t-caption text-subtle">Create a universe first to add memories.</p>
      ) : null}

      <Modal open={open} onClose={() => setOpen(false)} title="Add memory">
        <label className="flex flex-col gap-1.5">
          <Overline>Universe</Overline>
          <select value={uni} onChange={(e) => setUni(e.target.value)} className={selectCls}>
            {unis.map((u) => (
              <option key={u.id} value={u.id}>
                {u.name}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1.5">
          <Overline>Category</Overline>
          <select
            value={cat}
            onChange={(e) => setCat(e.target.value as MemoryCategory)}
            className={selectCls}
          >
            {CATS.map((c) => (
              <option key={c.key} value={c.key}>
                {c.label}
              </option>
            ))}
          </select>
        </label>
        <Field label="Memory" value={text} onChange={setText} textarea />
        <Button disabled={!text.trim() || !uni || save.isPending} onClick={() => save.mutate()}>
          {save.isPending ? "Saving…" : "Add"}
        </Button>
      </Modal>
    </div>
  );
}
