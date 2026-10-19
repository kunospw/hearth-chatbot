// Runs a golden scenario through the TypeScript engine. Shared by the golden
// test (pure engine) and the database round-trip test (engine + SQL).
import assert from 'node:assert/strict';
import { RelationshipEngine, inferFactTags, type EngineOutcome } from '../../functions/_shared/engine/engine.ts';
import { presetById } from '../../functions/_shared/engine/bands.ts';
import {
  REL_VALUES,
  canUndo,
  deriveLedger,
  magnitude,
  type Deltas,
  type Relationship,
} from '../../functions/_shared/engine/models.ts';

// deno-lint-ignore no-explicit-any
export type Json = Record<string, any>;

const round9 = (v: number): number => Math.round(v * 1e9) / 1e9;

/**
 * The relationship as the golden file records it: ids become #1, #2… in order
 * of appearance, numbers are rounded, key order is fixed. [unmap] turns a
 * message / conversation id back into its scenario label.
 */
export function normState(r: Relationship, unmap: (x: string) => string = (x) => x): Json {
  const ids = new Map<string, string>();
  const id = (x: string | null): string | null => {
    if (x === null) return null;
    if (!ids.has(x)) ids.set(x, `#${ids.size + 1}`);
    return ids.get(x)!;
  };
  const label = (x: string | null): string | null => (x === null ? null : unmap(x));
  const deltas = (d: Deltas): Json => {
    const o: Json = {};
    for (const k of REL_VALUES) if (d[k] !== undefined) o[k] = round9(d[k]!);
    return o;
  };
  const mults = (m: Record<string, number>): Json => {
    const o: Json = {};
    for (const k of Object.keys(m).sort()) o[k] = round9(m[k]);
    return o;
  };
  r.events.forEach((e) => id(e.id));
  r.pending.forEach((p) => id(p.id));
  r.facts.forEach((f) => id(f.id));
  return {
    type: r.type,
    pacing: r.pacing,
    values: Object.fromEntries(REL_VALUES.map((k) => [k, round9(r.values[k])])),
    stages: r.stages,
    stageIdx: r.stageIdx,
    stageLocked: r.stageLocked,
    romanticFrom: r.romanticFrom,
    turn: r.turn,
    ignored: r.ignored,
    recentHashes: r.recentHashes,
    facts: r.facts.map((f) => ({ id: id(f.id), text: f.text, locked: f.locked, tags: f.tags })),
    events: r.events.map((e) => ({
      id: id(e.id),
      kindId: e.kindId,
      category: e.category,
      title: e.title,
      at: e.at.toISOString(),
      why: e.why,
      source: e.source,
      deltas: deltas(e.deltas),
      multipliers: mults(e.multipliers),
      evidence: e.evidence,
      chatTitle: e.chatTitle,
      conversationId: label(e.conversationId),
      messageId: label(e.messageId),
      turn: e.turn,
      stageBefore: e.stageBefore,
      stageAfter: e.stageAfter,
      undoable: e.undoable,
      undoneBy: id(e.undoneBy),
      undoOf: id(e.undoOf),
      fromDeletedChat: e.fromDeletedChat,
    })),
    pending: r.pending.map((p) => ({
      id: id(p.id),
      kindId: p.kindId,
      category: p.category,
      title: p.title,
      deltas: deltas(p.deltas),
      multipliers: mults(p.multipliers),
      why: p.why,
      at: p.at.toISOString(),
      turn: p.turn,
      chatTitle: p.chatTitle,
      conversationId: label(p.conversationId),
      messageId: label(p.messageId),
      evidence: p.evidence,
      source: p.source,
    })),
  };
}

export interface RunOptions {
  /** Ids for new events, suggestions and facts (the golden test uses a counter). */
  newId?: (prefix: string) => string;
  /** Message and conversation labels from the scenario → the ids the engine sees. */
  mapLabel?: (label: string) => string;
  /** Called after every step with the state before and after it. */
  onStep?: (info: { index: number; op: string; step: Json; prev: Relationship; next: Relationship }) => void;
  /** Initial facts get ids from here (default init0, init1…). */
  factId?: (i: number) => string;
  relationshipId?: string;
}

export interface Run {
  name: string;
  initial: Relationship;
  steps: Json[];
  final: Relationship;
}

export function initialState(sc: Json, o: RunOptions = {}): Relationship {
  const setup = sc.setup as Json;
  const preset = presetById(setup.preset);
  const v = (setup.values ?? {}) as Json;
  return {
    id: o.relationshipId ?? 'r',
    characterId: 'c',
    personaId: 'p',
    universeId: null,
    type: setup.type,
    pacing: setup.pacing,
    values: {
      trust: v.trust ?? 20,
      affection: v.affection ?? 15,
      attraction: v.attraction ?? 0,
      tension: v.tension ?? 0,
    },
    stages: [...preset.stages],
    stageIdx: setup.stageIdx ?? 1,
    stageLocked: false,
    romanticFrom: preset.romanticFrom,
    facts: ((setup.facts ?? []) as Json[]).map((f, i) => ({
      id: o.factId ? o.factId(i) : `init${i}`,
      text: f.text,
      locked: f.locked,
      tags: inferFactTags(f.text),
    })),
    events: [],
    pending: [],
    ledger: [],
    recentHashes: [],
    turn: 0,
    ignored: 0,
    version: 0,
  };
}

export function run(sc: Json, o: RunOptions = {}): Run {
  const map = o.mapLabel ?? ((x: string) => x);
  const initial = initialState(sc, o);
  let r = initial;
  let counter = 0;
  const engine = new RelationshipEngine((p) => (o.newId ? o.newId(p) : `${p}${++counter}`));
  let clock = Date.UTC(2026, 2, 10, 9);
  const steps: Json[] = [];

  (sc.steps as Json[]).forEach((s, i) => {
    clock += 60_000;
    const prev = r;
    let outcome = 'ok';
    let note: string | null = null;
    const now = () => new Date(clock);
    const describe = (out: EngineOutcome): string => {
      r = out.relationship;
      if (out.kind === 'ignored') return `ignored:${out.reason}:${out.counted}`;
      note = `${out.note.text} | ${out.note.story}`;
      return out.kind;
    };
    const turn = (messageId: string, text: string) => ({
      messageId: map(messageId),
      text,
      now: now(),
      conversationId: s.conv === undefined ? null : map(s.conv),
      chatTitle: 'Chat',
    });

    switch (s.op) {
      case 'user':
        outcome = describe(engine.processUserMessage(r, turn(s.message ?? `m${i}`, s.text)));
        break;
      case 'filler':
        for (let k = 0; k < s.count; k++) {
          clock += 60_000;
          r = engine.processUserMessage(r, turn(`f${i}_${k}`, `just talking about the weather number ${i} ${k}`)).relationship;
        }
        break;
      case 'edit':
        outcome = describe(engine.reevaluateEdited(r, turn(s.message, s.text)));
        break;
      case 'proposal':
        outcome = describe(
          engine.processModelProposal(
            r,
            {
              kindId: s.kind,
              evidence: s.evidence,
              reason: s.reason,
              messageId: map(s.message),
              recentMessages: s.recent,
              now: now(),
              conversationId: s.conv === undefined ? null : map(s.conv),
              chatTitle: 'Chat',
            },
            { characterFirst: 'Vesper' },
          ),
        );
        break;
      case 'undo': {
        const e = r.events.find((x) => x.kindId === s.kind && canUndo(x));
        if (e === undefined) outcome = 'noop';
        else r = engine.undo(r, e.id, { now: now() });
        break;
      }
      case 'accept':
        if (r.pending.length === 0) outcome = 'noop';
        else r = engine.acceptSuggestion(r, r.pending[0].id, { now: now() });
        break;
      case 'dismiss':
        if (r.pending.length === 0) outcome = 'noop';
        else r = engine.dismissSuggestion(r, r.pending[0].id);
        break;
      case 'correct':
        r = engine.applyCorrection(r, s.values, { reason: s.reason ?? null, now: now() });
        break;
      case 'setType':
        r = engine.setType(r, s.type);
        break;
      case 'setPacing':
        r = engine.setPacing(r, s.pacing);
        break;
      case 'preset':
        r = engine.applyPreset(r, presetById(s.id));
        break;
      case 'stages':
        r = engine.saveStages(r, s.names, s.current, s.lock, { now: now() });
        break;
      case 'addFact':
        r = engine.addFact(r, s.text, { locked: s.locked });
        break;
      case 'factLock': {
        const f = r.facts.find((x) => x.text === s.text);
        if (f) r = engine.setFactLocked(r, f.id, s.locked);
        break;
      }
      case 'removeFact': {
        const f = r.facts.find((x) => x.text === s.text);
        if (f) r = engine.removeFact(r, f.id);
        break;
      }
      case 'deleteChat':
        r = engine.markChatDeleted(r, map(s.conv));
        break;
      case 'tick':
        clock += s.minutes * 60_000;
        break;
      case 'nextDay':
        clock += 24 * 3_600_000;
        break;
      default:
        throw new Error(`unknown op ${s.op}`);
    }

    // The server does not keep the ledger: it derives it from events and
    // suggestions. That derivation must agree with the carried ledger.
    const key = (l: { kindId: string; turn: number; deltas: Deltas }) =>
      `${l.turn}|${l.kindId}|${JSON.stringify(REL_VALUES.map((k) => l.deltas[k] ?? 0))}`;
    const derived = deriveLedger(r.events, r.pending);
    assert.deepEqual(derived.map(key).sort(), r.ledger.map(key).sort(), `${sc.name} step ${i} (${s.op}): derived ledger differs`);
    assert.equal(
      derived.reduce((a, l) => a + magnitude(l), 0),
      r.ledger.reduce((a, l) => a + magnitude(l), 0),
    );

    steps.push({ op: s.op, outcome, note, state: normState(r, o.mapLabel ? undefined : undefined) });
    o.onStep?.({ index: i, op: s.op, step: s, prev, next: r });
  });
  return { name: sc.name, initial, steps, final: r };
}
