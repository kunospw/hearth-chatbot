import type { BackendApi } from "@/lib/backend/api";
import { type Relationship, relationshipFromJson } from "./types";

// The relationship journal is READ through the database (RLS applies); all
// WRITES go through the edge functions (chat_turn / apply_correction), never
// from here. Mirrors the server relationship backend in the Flutter app.

/**
 * Create-on-first-use: returns the relationship for this character + persona,
 * creating the default starting point if it does not exist yet. It cannot set
 * a value. RPC: ensure_relationship(p_character, p_persona).
 */
export async function ensureRelationship(
  api: BackendApi,
  characterId: string,
  personaId: string,
): Promise<Relationship | null> {
  const json = await api.rpc("ensure_relationship", {
    p_character: characterId,
    p_persona: personaId,
  });
  return relationshipFromJson(json);
}

/** Reload one relationship by id. RPC: relationship_snapshot(p_id). */
export async function relationshipSnapshot(
  api: BackendApi,
  id: string,
): Promise<Relationship | null> {
  const json = await api.rpc("relationship_snapshot", { p_id: id });
  return relationshipFromJson(json);
}

/**
 * A journal action (undo, approve/dismiss a suggestion, correct, set type,
 * pacing, stages or a fact). The edge function validates and persists it, then
 * returns the fresh snapshot. Mirrors apply_correction in the Flutter app.
 */
export async function applyCorrection(
  api: BackendApi,
  body: Record<string, unknown>,
): Promise<Relationship | null> {
  const res = await api.invoke("apply_correction", body);
  return relationshipFromJson(res.relationship ?? res);
}
