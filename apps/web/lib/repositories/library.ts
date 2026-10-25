import type { BackendApi } from "@/lib/backend/api";
import type {
  MemoryRow,
  PersonaRow,
  UniverseRow,
} from "@/lib/backend/database.types";
import { BackendError } from "@/lib/backend/errors";
import {
  memoryFromRow,
  memoryToRow,
  personaFromRow,
  personaToRow,
  universeFromRow,
  universeToRow,
} from "@/lib/backend/mappers";
import type { Memory, Persona, Universe } from "@/lib/domain/types";

async function uid(api: BackendApi): Promise<string> {
  const id = await api.currentUserId();
  if (!id) throw new BackendError(401, "unauthorized", "Sign in first.");
  return id;
}

// ── universes ──────────────────────────────────────────────────────────────

export async function listUniverses(api: BackendApi): Promise<Universe[]> {
  const rows = await api.select<UniverseRow>("universes", { orderBy: "created_at" });
  return rows.map(universeFromRow);
}

export async function saveUniverse(api: BackendApi, u: Universe): Promise<void> {
  await api.upsert("universes", universeToRow(u, await uid(api)));
}

export async function deleteUniverse(api: BackendApi, id: string): Promise<void> {
  await api.delete("universes", { id });
}

// ── memories ─────────────────────────────────────────────────────────────

export async function listMemories(
  api: BackendApi,
  universeId?: string,
): Promise<Memory[]> {
  const rows = await api.select<MemoryRow>("memories", {
    orderBy: "created_at",
    eq: universeId ? { universe_id: universeId } : undefined,
  });
  return rows.map(memoryFromRow);
}

export async function saveMemory(api: BackendApi, m: Memory): Promise<void> {
  await api.upsert("memories", memoryToRow(m, await uid(api)));
}

export async function deleteMemory(api: BackendApi, id: string): Promise<void> {
  await api.delete("memories", { id });
}

// ── personas ─────────────────────────────────────────────────────────────

export async function listPersonas(api: BackendApi): Promise<Persona[]> {
  const rows = await api.select<PersonaRow>("personas", { orderBy: "created_at" });
  return rows.map(personaFromRow);
}

export async function savePersona(api: BackendApi, p: Persona): Promise<void> {
  await api.upsert("personas", personaToRow(p, await uid(api)));
}

export async function deletePersona(api: BackendApi, id: string): Promise<void> {
  await api.delete("personas", { id });
}

/** Makes one persona the default (one default per user). */
export async function setDefaultPersona(api: BackendApi, id: string): Promise<void> {
  await api.update("personas", { is_default: false }, {});
  await api.update("personas", { is_default: true }, { id });
}
