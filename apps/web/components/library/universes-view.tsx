"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useSession } from "@/components/providers/session";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Field } from "@/components/ui/field";
import { PlusIcon } from "@/components/ui/icons";
import { Modal } from "@/components/ui/modal";
import { hexToArgb } from "@/lib/backend/color";
import type { Universe } from "@/lib/domain/types";
import { deleteUniverse, listUniverses, saveUniverse } from "@/lib/repositories/library";
import { getClientBackend } from "@/lib/supabase/client";
import { PreviewNotice } from "./preview-notice";

export function UniversesView() {
  const { configured, session } = useSession();
  const useReal = configured && !!session;
  const qc = useQueryClient();
  const { data } = useQuery({
    queryKey: ["universes"],
    queryFn: () => listUniverses(getClientBackend()),
    enabled: useReal,
  });
  const universes = data ?? [];

  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [era, setEra] = useState("");
  const [description, setDescription] = useState("");

  const save = useMutation({
    mutationFn: async () => {
      const u: Universe = {
        id: crypto.randomUUID(),
        name: name.trim(),
        era: era.trim() || "Your own world",
        tile: hexToArgb("#2E2A1F"),
        description,
      };
      await saveUniverse(getClientBackend(), u);
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["universes"] });
      setOpen(false);
      setName("");
      setEra("");
      setDescription("");
    },
  });

  const del = useMutation({
    mutationFn: (id: string) => deleteUniverse(getClientBackend(), id),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["universes"] }),
  });

  if (!useReal) return <PreviewNotice kind="universes" />;

  return (
    <div className="flex flex-col gap-3">
      {universes.length === 0 ? (
        <p className="t-body text-muted">No universes yet.</p>
      ) : (
        universes.map((u) => (
          <Card key={u.id} className="p-4 flex flex-col gap-1">
            <div className="t-label">{u.name}</div>
            <div className="t-caption">{u.era}</div>
            {u.description ? <p className="t-caption text-muted">{u.description}</p> : null}
            <button
              type="button"
              className="self-start t-caption text-danger mt-1"
              onClick={() => del.mutate(u.id)}
            >
              Delete
            </button>
          </Card>
        ))
      )}
      <Button variant="ghost" className="self-start" onClick={() => setOpen(true)}>
        <PlusIcon size={18} /> New universe
      </Button>

      <Modal open={open} onClose={() => setOpen(false)} title="New universe">
        <Field label="Name" value={name} onChange={setName} placeholder="e.g. The Drowned Coast" />
        <Field label="Era" value={era} onChange={setEra} placeholder="Optional" />
        <Field label="Description" value={description} onChange={setDescription} textarea />
        <Button disabled={!name.trim() || save.isPending} onClick={() => save.mutate()}>
          {save.isPending ? "Saving…" : "Create"}
        </Button>
      </Modal>
    </div>
  );
}
