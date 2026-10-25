// The relationship snapshot the server returns (camelCase JSON from
// relationship_snapshot() in supabase/migrations/..._functions.sql). The
// backend owns all values; the client only reads and displays them.

export interface RelationshipValues {
  trust: number;
  affection: number;
  attraction: number;
  tension: number;
}

export interface RelationshipFact {
  id: string;
  text: string;
  locked: boolean;
  tags: string[];
}

export interface RelationshipEvent {
  id: string;
  kindId: string;
  category: string;
  title: string;
  at: string;
  why: string;
  source: string; // engine | modelProposal | user | undo | approved | setup
  deltas: Record<string, number>;
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

export interface RelationshipSuggestion {
  id: string;
  kindId: string;
  category: string;
  title: string;
  deltas: Record<string, number>;
  multipliers: Record<string, number>;
  why: string;
  evidence: string | null;
  source: string;
  chatTitle: string;
  conversationId: string | null;
  messageId: string | null;
  turn: number;
  at: string;
}

export interface Relationship {
  id: string;
  characterId: string;
  personaId: string | null;
  universeId: string | null;
  type: string;
  pacing: string;
  values: RelationshipValues;
  stages: string[];
  stageIdx: number;
  stageLocked: boolean;
  romanticFrom: number | null;
  turn: number;
  ignored: number;
  version: number;
  facts: RelationshipFact[];
  events: RelationshipEvent[];
  pending: RelationshipSuggestion[];
}

const num = (v: unknown, d = 0): number => (typeof v === "number" ? v : Number(v) || d);
const str = (v: unknown): string => (typeof v === "string" ? v : "");
const obj = (v: unknown): Record<string, unknown> =>
  v && typeof v === "object" ? (v as Record<string, unknown>) : {};
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);

function values(v: unknown): RelationshipValues {
  const o = obj(v);
  return {
    trust: num(o.trust),
    affection: num(o.affection),
    attraction: num(o.attraction),
    tension: num(o.tension),
  };
}

function numMap(v: unknown): Record<string, number> {
  const o = obj(v);
  const out: Record<string, number> = {};
  for (const [k, val] of Object.entries(o)) out[k] = num(val);
  return out;
}

function fact(v: unknown): RelationshipFact {
  const o = obj(v);
  return {
    id: str(o.id),
    text: str(o.text),
    locked: o.locked === true,
    tags: arr(o.tags).map(String),
  };
}

function event(v: unknown): RelationshipEvent {
  const o = obj(v);
  return {
    id: str(o.id),
    kindId: str(o.kindId),
    category: str(o.category),
    title: str(o.title),
    at: str(o.at),
    why: str(o.why),
    source: str(o.source),
    deltas: numMap(o.deltas),
    multipliers: numMap(o.multipliers),
    evidence: (o.evidence as string) ?? null,
    chatTitle: str(o.chatTitle),
    conversationId: (o.conversationId as string) ?? null,
    messageId: (o.messageId as string) ?? null,
    turn: num(o.turn),
    stageBefore: o.stageBefore == null ? null : num(o.stageBefore),
    stageAfter: o.stageAfter == null ? null : num(o.stageAfter),
    undoable: o.undoable === true,
    undoneBy: (o.undoneBy as string) ?? null,
    undoOf: (o.undoOf as string) ?? null,
    fromDeletedChat: o.fromDeletedChat === true,
  };
}

function suggestion(v: unknown): RelationshipSuggestion {
  const o = obj(v);
  return {
    id: str(o.id),
    kindId: str(o.kindId),
    category: str(o.category),
    title: str(o.title),
    deltas: numMap(o.deltas),
    multipliers: numMap(o.multipliers),
    why: str(o.why),
    evidence: (o.evidence as string) ?? null,
    source: str(o.source),
    chatTitle: str(o.chatTitle),
    conversationId: (o.conversationId as string) ?? null,
    messageId: (o.messageId as string) ?? null,
    turn: num(o.turn),
    at: str(o.at),
  };
}

export function relationshipFromJson(v: unknown): Relationship | null {
  if (!v || typeof v !== "object") return null;
  const o = v as Record<string, unknown>;
  if (!o.id) return null;
  return {
    id: str(o.id),
    characterId: str(o.characterId),
    personaId: (o.personaId as string) ?? null,
    universeId: (o.universeId as string) ?? null,
    type: str(o.type),
    pacing: str(o.pacing),
    values: values(o.values),
    stages: arr(o.stages).map(String),
    stageIdx: num(o.stageIdx),
    stageLocked: o.stageLocked === true,
    romanticFrom: o.romanticFrom == null ? null : num(o.romanticFrom),
    turn: num(o.turn),
    ignored: num(o.ignored),
    version: num(o.version),
    facts: arr(o.facts).map(fact),
    events: arr(o.events).map(event),
    pending: arr(o.pending).map(suggestion),
  };
}
