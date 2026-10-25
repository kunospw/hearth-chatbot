"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { useSession } from "@/components/providers/session";
import { Button } from "@/components/ui/button";
import { Field } from "@/components/ui/field";
import { PlusIcon } from "@/components/ui/icons";
import { Modal } from "@/components/ui/modal";
import type { Persona } from "@/lib/domain/types";
import { deletePersona, listPersonas, savePersona } from "@/lib/repositories/library";
import { getClientBackend } from "@/lib/supabase/client";
import { PreviewNotice } from "./preview-notice";

const ACTIVE_KEY = "hearth-persona";

export function PersonasView() {
  const { configured, session } = useSession();
  const useReal = configured && !!session;
  const qc = useQueryClient();
  const { data } = useQuery({
    queryKey: ["personas"],
    queryFn: () => listPersonas(getClientBackend()),
    enabled: useReal,
  });
  const personas = data ?? [];

  const [active, setActive] = useState<string | null>(null);
  useEffect(() => {
    try {
      setActive(localStorage.getItem(ACTIVE_KEY));
    } catch {
      /* ignore */
    }
  }, []);
  const choose = (id: string) => {
    setActive(id);
    try {
      localStorage.setItem(ACTIVE_KEY, id);
    } catch {
      /* ignore */
    }
  };

  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");

  const save = useMutation({
    mutationFn: async () => {
      const p: Persona = {
        id: crypto.randomUUID(),
        name: name.trim(),
        initial: name.trim().slice(0, 1).toUpperCase(),
        description,
      };
      await savePersona(getClientBackend(), p);
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["personas"] });
      setOpen(false);
      setName("");
      setDescription("");
    },
  });

  const del = useMutation({
    mutationFn: (id: string) => deletePersona(getClientBackend(), id),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["personas"] }),
  });

  if (!useReal) return <PreviewNotice kind="personas" />;

  return (
    <div className="flex flex-col gap-2">
      <p className="t-caption text-subtle">The voice you play as in a chat.</p>
      {personas.map((p) => (
        <label
          key={p.id}
          className="flex items-center gap-3 rounded-field border border-outline bg-surface px-3 py-3 cursor-pointer"
        >
          <input
            type="radio"
            name="persona"
            checked={active === p.id}
            onChange={() => choose(p.id)}
            className="accent-[var(--primary)]"
          />
          <div className="min-w-0 flex-1">
            <div className="t-label">{p.name}</div>
            {p.description ? <div className="t-caption text-muted truncate">{p.description}</div> : null}
          </div>
          <button
            type="button"
            className="t-caption text-danger"
            onClick={(e) => {
              e.preventDefault();
              del.mutate(p.id);
            }}
          >
            Delete
          </button>
        </label>
      ))}
      <Button variant="ghost" className="self-start mt-1" onClick={() => setOpen(true)}>
        <PlusIcon size={18} /> New persona
      </Button>

      <Modal open={open} onClose={() => setOpen(false)} title="New persona">
        <Field label="Name" value={name} onChange={setName} placeholder="e.g. A quiet traveller" />
        <Field label="Description" value={description} onChange={setDescription} textarea />
        <Button disabled={!name.trim() || save.isPending} onClick={() => save.mutate()}>
          {save.isPending ? "Saving…" : "Create"}
        </Button>
      </Modal>
    </div>
  );
}
