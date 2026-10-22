// Turning an engine result into the patch commit_relationship() applies.
//
// The edge function loads a snapshot, runs the engine (which returns a whole new
// Relationship), and sends only what changed. The database applies it in one
// transaction guarded by `version`.
import {
  eventToJson,
  suggestionToJson,
  type Relationship,
} from './models.ts';

export interface RelationshipPatch {
  startingPoint?: string;
  type?: string;
  pacing?: string;
  values?: Relationship['values'];
  stageIdx?: number;
  stageLocked?: boolean;
  /** Present (even as null) only when it changed. */
  romanticFrom?: number | null;
  turn?: number;
  ignored?: number;
  recentHashes?: string[];
  stages?: string[];
  facts?: { upsert?: unknown[]; delete?: string[] };
  /** Oldest first. An event with `undoOf` strikes the original through. */
  events?: { insert: unknown[] };
  suggestions?: { insert?: unknown[]; delete?: string[] };
}

const same = (a: unknown, b: unknown): boolean => JSON.stringify(a) === JSON.stringify(b);

/** What changed between two states of the same relationship. */
export function diffRelationship(prev: Relationship, next: Relationship): RelationshipPatch {
  const p: RelationshipPatch = {};
  if (prev.startingPoint !== next.startingPoint) p.startingPoint = next.startingPoint;
  if (prev.type !== next.type) p.type = next.type;
  if (prev.pacing !== next.pacing) p.pacing = next.pacing;
  if (!same(prev.values, next.values)) p.values = next.values;
  if (prev.stageIdx !== next.stageIdx) p.stageIdx = next.stageIdx;
  if (prev.stageLocked !== next.stageLocked) p.stageLocked = next.stageLocked;
  if (prev.romanticFrom !== next.romanticFrom) p.romanticFrom = next.romanticFrom;
  if (prev.turn !== next.turn) p.turn = next.turn;
  if (prev.ignored !== next.ignored) p.ignored = next.ignored;
  if (!same(prev.recentHashes, next.recentHashes)) p.recentHashes = next.recentHashes;
  if (!same(prev.stages, next.stages)) p.stages = next.stages;

  const prevFacts = new Map(prev.facts.map((f) => [f.id, f]));
  const nextIds = new Set(next.facts.map((f) => f.id));
  const upsert = next.facts.filter((f) => !same(prevFacts.get(f.id), f));
  const del = prev.facts.filter((f) => !nextIds.has(f.id)).map((f) => f.id);
  if (upsert.length > 0 || del.length > 0) {
    p.facts = {};
    if (upsert.length > 0) p.facts.upsert = upsert;
    if (del.length > 0) p.facts.delete = del;
  }

  // The log is append-only: new events are a prefix of the newest-first list.
  const known = new Set(prev.events.map((e) => e.id));
  const added = next.events.filter((e) => !known.has(e.id));
  if (added.length > 0) p.events = { insert: added.map(eventToJson).reverse() };

  const prevPending = new Set(prev.pending.map((s) => s.id));
  const nextPending = new Set(next.pending.map((s) => s.id));
  const sInsert = next.pending.filter((s) => !prevPending.has(s.id));
  const sDelete = prev.pending.filter((s) => !nextPending.has(s.id)).map((s) => s.id);
  if (sInsert.length > 0 || sDelete.length > 0) {
    p.suggestions = {};
    if (sInsert.length > 0) p.suggestions.insert = sInsert.map(suggestionToJson).reverse();
    if (sDelete.length > 0) p.suggestions.delete = sDelete;
  }
  return p;
}

export const isEmptyPatch = (p: RelationshipPatch): boolean => Object.keys(p).length === 0;
