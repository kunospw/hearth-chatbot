// Relationship models. A TypeScript port of
// lib/features/relationship/domain/relationship_models.dart: the Dart file is
// the reference, and supabase/tests/golden/* proves both engines agree.
//
// Plain TypeScript with no runtime-specific imports, so it runs under Deno
// (edge functions) and Node (tests).

export type RelValue = 'trust' | 'affection' | 'attraction' | 'tension';
export const REL_VALUES: readonly RelValue[] = ['trust', 'affection', 'attraction', 'tension'];

export const REL_LABEL: Record<RelValue, string> = {
  trust: 'Trust',
  affection: 'Affection',
  attraction: 'Attraction',
  tension: 'Tension',
};

export type RelationType =
  | 'undecided'
  | 'platonic'
  | 'romantic'
  | 'familial'
  | 'rivalrous'
  | 'other';

export const RELATION_TYPES: readonly RelationType[] = [
  'undecided',
  'platonic',
  'romantic',
  'familial',
  'rivalrous',
  'other',
];

export const RELATION_LABEL: Record<RelationType, string> = {
  undecided: 'Let the story decide',
  platonic: 'Platonic',
  romantic: 'Romantic',
  familial: 'Family',
  rivalrous: 'Rivalry',
  other: 'Something else',
};

/** Romance is only possible when the type is Romantic or Let the story decide. */
export const romanceAllowed = (t: RelationType): boolean => t === 'romantic' || t === 'undecided';

export type RelPacing = 'slow' | 'balanced' | 'fast' | 'manual';
export const PACINGS: readonly RelPacing[] = ['slow', 'balanced', 'fast', 'manual'];

/** Multipliers for gains (`up`) and setbacks (`down`). */
export const PACING: Record<RelPacing, { label: string; up: number; down: number }> = {
  slow: { label: 'Slow burn', up: 0.5, down: 0.75 },
  balanced: { label: 'Balanced', up: 1, down: 1 },
  fast: { label: 'Fast', up: 1.6, down: 1.2 },
  manual: { label: 'Manual', up: 1, down: 1 },
};

export type TimelineKind = 'milestone' | 'setback' | 'reconcile' | 'shift' | 'correction';

export type EventSource = 'engine' | 'modelProposal' | 'user' | 'undo' | 'approved' | 'setup';

export type Deltas = Partial<Record<RelValue, number>>;

export interface Values {
  trust: number;
  affection: number;
  attraction: number;
  tension: number;
}

export const DEFAULT_VALUES: Values = { trust: 20, affection: 15, attraction: 0, tension: 0 };

/** Adds [deltas], keeping every value between 0 and 100. */
export function plusValues(v: Values, deltas: Deltas): Values {
  const out = { ...v };
  for (const k of REL_VALUES) {
    const d = deltas[k];
    if (d !== undefined) out[k] = Math.min(100, Math.max(0, out[k] + d));
  }
  return out;
}

export interface Fact {
  id: string;
  text: string;
  locked: boolean;
  tags: string[];
}

export interface RelationshipEvent {
  id: string;
  kindId: string | null;
  category: TimelineKind;
  title: string;
  at: Date;
  why: string;
  source: EventSource;
  deltas: Deltas;
  multipliers: Record<string, number>;
  evidence: string | null;
  chatTitle: string;
  conversationId: string | null;
  messageId: string | null;
  turn: number;
  stageBefore: number | null;
  stageAfter: number | null;
  undoable: boolean;
  undoneBy: string | null;
  undoOf: string | null;
  fromDeletedChat: boolean;
}

export const isUndone = (e: RelationshipEvent): boolean => e.undoneBy !== null;
export const canUndo = (e: RelationshipEvent): boolean => e.undoable && !isUndone(e);

export interface Suggestion {
  id: string;
  kindId: string;
  category: TimelineKind;
  title: string;
  deltas: Deltas;
  why: string;
  at: Date;
  turn: number;
  chatTitle: string;
  conversationId: string | null;
  messageId: string | null;
  evidence: string | null;
  multipliers: Record<string, number>;
  source: EventSource;
}

/** A moment that counted (or is waiting to). Derived from events + suggestions. */
export interface LedgerEntry {
  kindId: string;
  turn: number;
  at: Date;
  deltas: Deltas;
  eventId: string | null;
  suggestionId: string | null;
}

export const magnitude = (l: LedgerEntry): number =>
  Object.values(l.deltas).reduce((s: number, d) => s + Math.abs(d ?? 0), 0);

export interface Relationship {
  id: string;
  characterId: string;
  personaId: string;
  universeId: string | null;
  type: RelationType;
  pacing: RelPacing;
  values: Values;
  /** Six stage names. */
  stages: string[];
  stageIdx: number;
  stageLocked: boolean;
  /** First stage that needs romance (attraction) to be reached. */
  romanticFrom: number | null;
  facts: Fact[];
  /** Newest first. */
  events: RelationshipEvent[];
  pending: Suggestion[];
  ledger: LedgerEntry[];
  /** Normalised recent user messages as `turn|text`. */
  recentHashes: string[];
  turn: number;
  ignored: number;
  /** Owned by the database; the engine never bumps it. */
  version: number;
}

export const stageName = (r: Relationship): string =>
  r.stages[Math.min(Math.max(r.stageIdx, 0), r.stages.length - 1)];

/** The one line under a message when something shifted. Never numbers. */
export interface RelationshipNote {
  text: string;
  story: string;
  entryId: string | null;
  kindId: string | null;
  evidence: string | null;
  reason: string | null;
}

// ── JSON (the shape relationship_snapshot() returns, camelCase) ─────────────

type Json = Record<string, unknown>;

const num = (x: unknown, d = 0): number => (x === null || x === undefined ? d : Number(x));
const str = (x: unknown): string | null => (x === null || x === undefined ? null : String(x));

export function eventFromJson(j: Json): RelationshipEvent {
  return {
    id: String(j.id),
    kindId: str(j.kindId),
    category: j.category as TimelineKind,
    title: String(j.title ?? ''),
    at: new Date(String(j.at)),
    why: String(j.why ?? ''),
    source: j.source as EventSource,
    deltas: (j.deltas ?? {}) as Deltas,
    multipliers: (j.multipliers ?? {}) as Record<string, number>,
    evidence: str(j.evidence),
    chatTitle: String(j.chatTitle ?? 'Story'),
    conversationId: str(j.conversationId),
    messageId: str(j.messageId),
    turn: num(j.turn),
    stageBefore: j.stageBefore === null || j.stageBefore === undefined ? null : num(j.stageBefore),
    stageAfter: j.stageAfter === null || j.stageAfter === undefined ? null : num(j.stageAfter),
    undoable: Boolean(j.undoable),
    undoneBy: str(j.undoneBy),
    undoOf: str(j.undoOf),
    fromDeletedChat: Boolean(j.fromDeletedChat),
  };
}

export function suggestionFromJson(j: Json): Suggestion {
  return {
    id: String(j.id),
    kindId: String(j.kindId),
    category: j.category as TimelineKind,
    title: String(j.title ?? ''),
    deltas: (j.deltas ?? {}) as Deltas,
    why: String(j.why ?? ''),
    at: new Date(String(j.at)),
    turn: num(j.turn),
    chatTitle: String(j.chatTitle ?? 'Story'),
    conversationId: str(j.conversationId),
    messageId: str(j.messageId),
    evidence: str(j.evidence),
    multipliers: (j.multipliers ?? {}) as Record<string, number>,
    source: (j.source ?? 'engine') as EventSource,
  };
}

/**
 * Cooldowns, diminishing returns and the scene and daily budgets all read this
 * ledger. It is derived (not stored): an event that counted and was not undone,
 * plus every suggestion that is still waiting. Undoing an event therefore frees
 * its cooldown and budget again.
 */
export function deriveLedger(events: RelationshipEvent[], pending: Suggestion[]): LedgerEntry[] {
  const out: LedgerEntry[] = [];
  const counted: EventSource[] = ['engine', 'modelProposal', 'approved'];
  // oldest first, like the engine appends
  for (const e of [...events].reverse()) {
    if (e.kindId === null || e.undoneBy !== null || !counted.includes(e.source)) continue;
    if (e.kindId === 'undo' || e.kindId === 'correction') continue;
    out.push({
      kindId: e.kindId,
      turn: e.turn,
      at: e.at,
      deltas: e.deltas,
      eventId: e.id,
      suggestionId: null,
    });
  }
  for (const s of [...pending].reverse()) {
    out.push({
      kindId: s.kindId,
      turn: s.turn,
      at: s.at,
      deltas: s.deltas,
      eventId: null,
      suggestionId: s.id,
    });
  }
  return out;
}

export function relationshipFromJson(j: Json): Relationship {
  const v = (j.values ?? {}) as Json;
  const events = ((j.events ?? []) as Json[]).map(eventFromJson);
  const pending = ((j.pending ?? []) as Json[]).map(suggestionFromJson);
  return {
    id: String(j.id),
    characterId: String(j.characterId),
    personaId: String(j.personaId),
    universeId: str(j.universeId),
    type: j.type as RelationType,
    pacing: j.pacing as RelPacing,
    values: {
      trust: num(v.trust, 20),
      affection: num(v.affection, 15),
      attraction: num(v.attraction),
      tension: num(v.tension),
    },
    stages: ((j.stages ?? []) as unknown[]).map(String),
    stageIdx: num(j.stageIdx),
    stageLocked: Boolean(j.stageLocked),
    romanticFrom: j.romanticFrom === null || j.romanticFrom === undefined ? null : num(j.romanticFrom),
    facts: ((j.facts ?? []) as Json[]).map((f) => ({
      id: String(f.id),
      text: String(f.text),
      locked: Boolean(f.locked),
      tags: ((f.tags ?? []) as unknown[]).map(String),
    })),
    events,
    pending,
    ledger: deriveLedger(events, pending),
    recentHashes: ((j.recentHashes ?? []) as unknown[]).map(String),
    turn: num(j.turn),
    ignored: num(j.ignored),
    version: num(j.version),
  };
}

// ── JSON out (the same shape relationship_snapshot() returns) ───────────────

export function eventToJson(e: RelationshipEvent): Json {
  return {
    id: e.id,
    kindId: e.kindId,
    category: e.category,
    title: e.title,
    at: e.at.toISOString(),
    why: e.why,
    source: e.source,
    deltas: e.deltas,
    multipliers: e.multipliers,
    evidence: e.evidence,
    chatTitle: e.chatTitle,
    conversationId: e.conversationId,
    messageId: e.messageId,
    turn: e.turn,
    stageBefore: e.stageBefore,
    stageAfter: e.stageAfter,
    undoable: e.undoable,
    undoneBy: e.undoneBy,
    undoOf: e.undoOf,
    fromDeletedChat: e.fromDeletedChat,
  };
}

export function suggestionToJson(s: Suggestion): Json {
  return {
    id: s.id,
    kindId: s.kindId,
    category: s.category,
    title: s.title,
    deltas: s.deltas,
    multipliers: s.multipliers,
    why: s.why,
    evidence: s.evidence,
    source: s.source,
    chatTitle: s.chatTitle,
    conversationId: s.conversationId,
    messageId: s.messageId,
    turn: s.turn,
    at: s.at.toISOString(),
  };
}

export function relationshipToJson(r: Relationship): Json {
  return {
    id: r.id,
    characterId: r.characterId,
    personaId: r.personaId,
    universeId: r.universeId,
    type: r.type,
    pacing: r.pacing,
    values: { ...r.values },
    stages: r.stages,
    stageIdx: r.stageIdx,
    stageLocked: r.stageLocked,
    romanticFrom: r.romanticFrom,
    turn: r.turn,
    ignored: r.ignored,
    version: r.version,
    recentHashes: r.recentHashes,
    facts: r.facts.map((f) => ({ ...f })),
    events: r.events.map(eventToJson),
    pending: r.pending.map(suggestionToJson),
  };
}
