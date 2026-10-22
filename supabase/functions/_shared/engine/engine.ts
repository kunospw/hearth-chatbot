// The deterministic relationship engine (RELATIONSHIP_ENGINE.md, "Engine loop").
// Port of lib/features/relationship/domain/relationship_engine.dart. Every
// method takes a relationship and returns a new one; nothing is mutated.
//
// This is the ONLY place relationship numbers are computed. The Flutter app
// never runs it in production; it displays what the server returns.
import { EVENT_CATALOGUE, classifyUserText } from './catalogue.ts';
import { STAGE_PRESETS, STARTING_SETUPS, presetById, signed, stageFor, type StagePreset } from './bands.ts';
import {
  PACING,
  REL_LABEL,
  REL_VALUES,
  STARTING_LABEL,
  canUndo,
  isUndone,
  magnitude,
  plusValues,
  romanceAllowed,
  stageName,
  type Deltas,
  type EventSource,
  type Fact,
  type LedgerEntry,
  type RelValue,
  type Relationship,
  type RelationType,
  type RelationshipEvent,
  type RelationshipNote,
  type RelPacing,
  type StartingPoint,
  type Suggestion,
  type TimelineKind,
  type Values,
} from './models.ts';

export type IgnoreReason =
  | 'noMatch'
  | 'trivial'
  | 'duplicate'
  | 'unknownKind'
  | 'noEvidence'
  | 'cooldown'
  | 'earlierMissing'
  | 'tensionTooLow'
  | 'romanceOff'
  | 'contradictsFact'
  | 'sceneBudget'
  | 'tooSmall';

export interface UserTurn {
  messageId: string;
  text: string;
  now: Date;
  conversationId?: string | null;
  chatTitle?: string;
}

/** What the model proposed. Numbers are never accepted from the model. */
export interface ModelProposal {
  kindId: string;
  /** A quote from the last messages that backs the proposal up. */
  evidence: string;
  reason: string;
  messageId: string;
  /** The last messages (newest last); the evidence must appear in the last 6. */
  recentMessages: string[];
  now: Date;
  conversationId?: string | null;
  chatTitle?: string;
}

export type EngineOutcome =
  | { kind: 'applied'; relationship: Relationship; event: RelationshipEvent; stageEvent: RelationshipEvent | null; note: RelationshipNote }
  | { kind: 'suggested'; relationship: Relationship; suggestion: Suggestion; note: RelationshipNote }
  | { kind: 'ignored'; relationship: Relationship; reason: IgnoreReason; counted: boolean };

const SCENE_BUDGET = 8;
const SCENE_WINDOW = 10;
const DAILY_CAP = 12;
const REPEAT_WINDOW = 30;
const HASH_WINDOW = 20;
const EVIDENCE_WINDOW = 6;
const MIN_WORDS = 4;

/** Dart's double.round(): halves round away from zero (Math.round rounds them up). */
const roundHalfAway = (x: number): number => (x < 0 ? -Math.round(-x) : Math.round(x));
const roundHalf = (v: number): number => roundHalfAway(v * 2) / 2;
const clamp = (x: number, lo: number, hi: number): number => Math.min(hi, Math.max(lo, x));

/** Is this change good for the relationship? Tension up is a setback. */
const isGain = (k: RelValue, delta: number): boolean => (k === 'tension' ? delta < 0 : delta > 0);

/** Keys in insertion order (the catalogue order the Dart engine iterates in). */
const keysOf = (d: Deltas): RelValue[] => Object.keys(d) as RelValue[];

const utcDay = (d: Date): string => d.toISOString().slice(0, 10);

/** Lower-case words only, so repeats and quotes compare reliably. */
export function normalise(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Tags the engine uses to decide what a locked fact forbids. */
export function inferFactTags(text: string): string[] {
  const t = text.toLowerCase();
  const tags: string[] = [];
  if (
    /\b(siblings?|brothers?|sisters?|mother|father|parents?|cousins?|related by blood)\b/.test(t) &&
    !/\bnot (related|siblings?)\b/.test(t)
  ) {
    tags.push('family');
  }
  if (/\b(just friends|only friends|platonic)\b/.test(t)) tags.push('platonic-only');
  if (/\b(never breaks? (a |their |her |his )?promises?|always keeps? (a |their |her |his )?(promise|word)s?)\b/.test(t)) {
    tags.push('keeps-promises');
  }
  if (/\b(loyal|never betray|would never betray)\b/.test(t)) tags.push('loyal');
  return tags;
}

function mainDelta(d: Deltas): RelValue | null {
  let best: RelValue | null = null;
  for (const k of keysOf(d)) {
    const v = d[k];
    if (v === undefined) continue;
    // Dart: reduce((a, b) => a.abs() >= b.abs() ? a : b), in entry order.
    if (best === null || Math.abs(d[best]!) < Math.abs(v)) best = k;
  }
  return best;
}

/** The muted line under a message: never numbers. */
export function noteFor(
  deltas: Deltas,
  category: TimelineKind,
  o: { kindId?: string | null; evidence?: string | null; reason?: string | null; entryId?: string | null } = {},
): RelationshipNote {
  const main = mainDelta(deltas)!;
  const up = deltas[main]! > 0;
  const small = Math.abs(deltas[main]!) < 2;
  const text =
    main === 'tension'
      ? up
        ? 'Tension rose'
        : 'Tension eased'
      : `${REL_LABEL[main]} ${up ? 'grew' : 'slipped'}${small ? ' a little' : ''}`;
  const story =
    category === 'setback'
      ? 'A distance opened between you.'
      : category === 'reconcile'
        ? 'Something mended, a little.'
        : 'Something shifted between you.';
  return {
    text,
    story,
    entryId: o.entryId ?? null,
    kindId: o.kindId ?? null,
    evidence: o.evidence ?? null,
    reason: o.reason ?? null,
  };
}

export type IdGen = (prefix: 'e' | 'p' | 'f') => string;

export class RelationshipEngine {
  readonly newId: IdGen;

  constructor(newId: IdGen) {
    this.newId = newId;
  }

  // ── a user message ──────────────────────────────────────────────────────

  /** Classify → validate → apply. [reevaluation] re-runs an edited message. */
  processUserMessage(r: Relationship, t: UserTurn, o: { reevaluation?: boolean; turn?: number } = {}): EngineOutcome {
    const reevaluation = o.reevaluation ?? false;
    const already =
      r.events.some(
        (e) => e.messageId === t.messageId && !isUndone(e) && e.source !== 'modelProposal' && e.undoOf === null,
      ) || r.pending.some((p) => p.messageId === t.messageId);
    if (already) return ignored(r, 'duplicate', false);

    const thisTurn = o.turn ?? r.turn + 1;
    const norm = normalise(t.text);
    const ooc = /^\s*\(\(.*\)\)\s*$/s.test(t.text);
    const hashTurn = (h: string): number => {
      const n = parseInt(h.slice(0, h.indexOf('|')), 10);
      return Number.isNaN(n) ? 0 : n;
    };
    const repeated =
      !reevaluation &&
      r.recentHashes.some((h) => h.slice(h.indexOf('|') + 1) === norm && thisTurn - hashTurn(h) <= HASH_WINDOW);
    const hashes =
      ooc || reevaluation
        ? r.recentHashes
        : [...r.recentHashes.filter((h) => thisTurn - hashTurn(h) <= HASH_WINDOW), `${thisTurn}|${norm}`];
    const base: Relationship = { ...r, turn: reevaluation ? r.turn : thisTurn, recentHashes: hashes };

    const kindId = classifyUserText(t.text);
    if (kindId === null) return ignored(base, 'noMatch', false);

    const words = t.text.trim().split(/\s+/).length;
    const emojiOnly = !/[\p{L}\p{N}]/u.test(t.text);
    if (words < MIN_WORDS || ooc || emojiOnly || repeated) {
      return ignored(countIgnored(base), 'trivial', true);
    }

    const kind = EVENT_CATALOGUE[kindId];
    const label = kind.userLabel.toLowerCase();
    const excerpt = t.text.length > 70 ? `${t.text.slice(0, 70)}…` : t.text;
    return this.evaluate(base, kindId, thisTurn, {
      title: kind.userLabel,
      source: 'engine',
      lead: `Matched “${label}” in your message: “${excerpt}”.`,
      now: t.now,
      messageId: t.messageId,
      conversationId: t.conversationId ?? null,
      chatTitle: t.chatTitle ?? 'Story',
      evidence: null,
    });
  }

  /** A message was edited: reverse what the old text caused, then evaluate again. */
  reevaluateEdited(r: Relationship, t: UserTurn): EngineOutcome {
    let rel = r;
    let turn: number | undefined;
    for (const e of r.events.filter(
      (x) => x.messageId === t.messageId && !isUndone(x) && x.source !== 'modelProposal' && x.undoOf === null,
    )) {
      turn = e.turn;
      if (canUndo(e)) rel = this.undo(rel, e.id, { now: t.now, reason: 'You edited the message that caused this.' });
    }
    const stale = rel.pending.filter((p) => p.messageId === t.messageId);
    if (stale.length > 0) {
      turn ??= stale[0].turn;
      rel = {
        ...rel,
        pending: rel.pending.filter((p) => p.messageId !== t.messageId),
        ledger: rel.ledger.filter((l) => l.suggestionId === null || !stale.some((s) => s.id === l.suggestionId)),
      };
    }
    return this.processUserMessage(rel, t, { reevaluation: true, turn: turn ?? rel.turn });
  }

  // ── a proposal from the model ───────────────────────────────────────────

  processModelProposal(r: Relationship, p: ModelProposal, o: { characterFirst: string }): EngineOutcome {
    if (
      r.events.some((e) => e.messageId === p.messageId && e.kindId === p.kindId && !isUndone(e)) ||
      r.pending.some((s) => s.messageId === p.messageId && s.kindId === p.kindId)
    ) {
      return ignored(r, 'duplicate', false);
    }
    const kind = EVENT_CATALOGUE[p.kindId];
    if (kind === undefined || !Object.hasOwn(EVENT_CATALOGUE, p.kindId)) {
      return ignored(countIgnored(r), 'unknownKind', true);
    }
    const window = p.recentMessages.length <= EVIDENCE_WINDOW ? p.recentMessages : p.recentMessages.slice(-EVIDENCE_WINDOW);
    const haystack = normalise(window.join(' '));
    const needle = normalise(p.evidence);
    if (needle === '' || !haystack.includes(needle)) {
      return ignored(countIgnored(r), 'noEvidence', true);
    }
    const reason = p.reason.trim() === '' ? kind.userLabel : p.reason.trim();
    return this.evaluate(r, p.kindId, r.turn, {
      title: reason,
      source: 'modelProposal',
      lead: `${o.characterFirst} did something that counts: ${reason}. They said: “${p.evidence}”.`,
      evidence: p.evidence,
      now: p.now,
      messageId: p.messageId,
      conversationId: p.conversationId ?? null,
      chatTitle: p.chatTitle ?? 'Story',
    });
  }

  // ── validation and application ──────────────────────────────────────────

  private evaluate(
    r: Relationship,
    kindId: string,
    turn: number,
    o: {
      title: string;
      source: EventSource;
      lead: string;
      now: Date;
      messageId: string;
      evidence: string | null;
      conversationId: string | null;
      chatTitle: string;
    },
  ): EngineOutcome {
    const kind = EVENT_CATALOGUE[kindId];
    const no = (why: IgnoreReason): EngineOutcome => ignored(countIgnored(r), why, true);

    if (kind.romanceOnly && !romanceAllowed(r.type)) return no('romanceOff');
    if (kind.minTension !== undefined && r.values.tension <= kind.minTension) return no('tensionTooLow');
    if (kind.needsEarlier !== undefined && !r.events.some((e) => e.kindId === kind.needsEarlier && !isUndone(e))) {
      return no('earlierMissing');
    }
    for (const f of r.facts.filter((x) => x.locked)) {
      if (f.tags.some((tag) => kind.contradicts.includes(tag))) return no('contradictsFact');
    }

    // Cooldown: each kind counts at most once per `cooldown` user turns.
    const counted = r.ledger.filter((l) => l.kindId === kindId);
    if (counted.length > 0 && turn - Math.max(...counted.map((l) => l.turn)) < kind.cooldown) {
      return no('cooldown');
    }

    // Diminishing returns: × 1/(1 + 0.5·n), n = times it counted in the last 30 turns.
    const n = counted.filter((l) => turn - l.turn < REPEAT_WINDOW).length;
    const repeat = 1 / (1 + 0.5 * n);
    let deltas: Deltas = {};
    for (const k of keysOf(kind.deltas)) deltas[k] = kind.deltas[k]! * repeat;
    const multipliers: Record<string, number> = {};
    if (repeat !== 1) multipliers.repeat = repeat;

    // Scene budget: at most 8 points in total per 10 turns.
    const used = r.ledger.filter((l) => turn - l.turn < SCENE_WINDOW).reduce((s, l) => s + magnitude(l), 0);
    const room = clamp(SCENE_BUDGET - used, 0, SCENE_BUDGET);
    const mag = Object.values(deltas).reduce((s: number, d) => s + Math.abs(d ?? 0), 0);
    let capped = false;
    if (room <= 0) return no('sceneBudget');
    if (mag > room) {
      const f = room / mag;
      const scaled: Deltas = {};
      for (const k of keysOf(deltas)) scaled[k] = deltas[k]! * f;
      deltas = scaled;
      multipliers.budget = f;
      capped = true;
    }

    // Daily cap: ±12 per value per day.
    let dailyHit = false;
    const today = utcDay(o.now);
    const todays = r.ledger.filter((l) => utcDay(l.at) === today);
    const capDeltas: Deltas = {};
    for (const k of keysOf(deltas)) {
      const d = deltas[k]!;
      const pos = todays.reduce((s, l) => s + Math.max(l.deltas[k] ?? 0, 0), 0);
      const neg = todays.reduce((s, l) => s + Math.min(l.deltas[k] ?? 0, 0), 0);
      const out = d > 0 ? clamp(d, 0, clamp(DAILY_CAP - pos, 0, DAILY_CAP)) : clamp(d, -DAILY_CAP - neg, 0);
      if (out !== d) dailyHit = true;
      capDeltas[k] = out;
    }
    deltas = capDeltas;
    if (dailyHit) multipliers.daily = 0;

    // Pacing last: gains × up, setbacks × down; then round to 0.5.
    const pacing = PACING[r.pacing];
    const raw: Deltas = { ...kind.deltas };
    const paced: Deltas = {};
    for (const k of keysOf(deltas)) {
      const d = deltas[k]!;
      const v = roundHalf(d * (isGain(k, d) ? pacing.up : pacing.down));
      if (v !== 0) paced[k] = v;
    }
    deltas = paced;
    if (pacing.up !== 1 || pacing.down !== 1) {
      const lead = keysOf(kind.deltas)[0];
      multipliers.pacing = isGain(lead, kind.deltas[lead]!) ? pacing.up : pacing.down;
    }
    if (Object.keys(deltas).length === 0) return no('tooSmall');

    let why = o.lead + ` ${pacing.label} pacing: `;
    why += keysOf(raw)
      .map((k) => `${REL_LABEL[k]} ${signed(raw[k]!)} → ${deltas[k] === undefined ? '0' : signed(deltas[k]!)}`)
      .join(', ');
    why += '.';
    if (n > 0) why += ' A similar moment already counted, so this one weighs less.';
    if (capped) why += ' Capped: this scene has already moved things a lot.';
    if (dailyHit) why += ' Capped: this value has moved a lot today.';

    const id = this.newId('e');
    const note = noteFor(deltas, kind.category, {
      kindId,
      evidence: o.evidence,
      reason: o.source === 'modelProposal' ? o.title : null,
      entryId: id,
    });

    // Manual pacing: suggest instead of change.
    if (r.pacing === 'manual') {
      const sid = this.newId('p');
      const s: Suggestion = {
        id: sid,
        kindId,
        category: kind.category,
        title: o.title,
        deltas,
        why,
        at: o.now,
        turn,
        chatTitle: o.chatTitle,
        conversationId: o.conversationId,
        messageId: o.messageId,
        evidence: o.evidence,
        multipliers,
        source: o.source,
      };
      const next: Relationship = {
        ...r,
        pending: [s, ...r.pending],
        ledger: [...r.ledger, { kindId, turn, at: o.now, deltas, eventId: null, suggestionId: sid }],
      };
      return {
        kind: 'suggested',
        relationship: next,
        suggestion: s,
        note: {
          text: 'Suggested change · review it',
          story: 'The story suggests a shift.',
          entryId: null,
          kindId: null,
          evidence: null,
          reason: null,
        },
      };
    }

    const values = plusValues(r.values, deltas);
    const event: RelationshipEvent = {
      id,
      kindId,
      category: kind.category,
      title: o.title,
      at: o.now,
      why,
      source: o.source,
      deltas,
      multipliers,
      evidence: o.evidence,
      chatTitle: o.chatTitle,
      conversationId: o.conversationId,
      messageId: o.messageId,
      turn,
      stageBefore: r.stageIdx,
      stageAfter: null,
      undoable: true,
      undoneBy: null,
      undoOf: null,
      fromDeletedChat: false,
    };
    let next: Relationship = {
      ...r,
      values,
      events: [event, ...r.events],
      ledger: [...r.ledger, { kindId, turn, at: o.now, deltas, eventId: id, suggestionId: null }],
    };
    let stageEvent: RelationshipEvent | null = null;
    const idx = stageFor(next);
    if (idx !== next.stageIdx) {
      next = { ...next, stageIdx: idx };
      stageEvent = this.stageEntry(next, r.stageIdx, 'engine', o.now, o.chatTitle, o.conversationId);
      next = { ...next, events: [stageEvent, ...next.events] };
    }
    return { kind: 'applied', relationship: next, event, stageEvent, note };
  }

  // ── suggestions, undo, corrections ──────────────────────────────────────

  acceptSuggestion(r: Relationship, id: string, o: { now: Date }): Relationship {
    const s = r.pending.find((p) => p.id === id);
    if (s === undefined) return r;
    const eid = this.newId('e');
    const event: RelationshipEvent = {
      id: eid,
      kindId: s.kindId,
      category: s.category,
      title: s.title,
      at: o.now,
      why: `${s.why} Approved by you (Manual pacing).`,
      source: 'approved',
      deltas: s.deltas,
      multipliers: s.multipliers,
      evidence: s.evidence,
      chatTitle: s.chatTitle,
      conversationId: s.conversationId,
      messageId: s.messageId,
      turn: s.turn,
      stageBefore: r.stageIdx,
      stageAfter: null,
      undoable: true,
      undoneBy: null,
      undoOf: null,
      fromDeletedChat: false,
    };
    let next: Relationship = {
      ...r,
      values: plusValues(r.values, s.deltas),
      pending: r.pending.filter((p) => p.id !== id),
      events: [event, ...r.events],
      ledger: r.ledger.map((l) =>
        l.suggestionId === id ? { kindId: l.kindId, turn: l.turn, at: l.at, deltas: l.deltas, eventId: eid, suggestionId: null } : l,
      ),
    };
    const idx = stageFor(next);
    if (idx !== next.stageIdx) {
      const before = next.stageIdx;
      next = { ...next, stageIdx: idx };
      next = { ...next, events: [this.stageEntry(next, before, 'engine', o.now, s.chatTitle, s.conversationId), ...next.events] };
    }
    return next;
  }

  dismissSuggestion(r: Relationship, id: string): Relationship {
    // Declining a suggestion frees the kind's cooldown and its budget, like an undo.
    return {
      ...r,
      pending: r.pending.filter((p) => p.id !== id),
      ledger: r.ledger.filter((l) => l.suggestionId !== id),
      ignored: r.ignored + 1,
    };
  }

  /** A reversing event is added and the original is struck through. */
  undo(r: Relationship, eventId: string, o: { now: Date; reason?: string | null }): Relationship {
    const e = r.events.find((x) => x.id === eventId);
    if (e === undefined || !canUndo(e)) return r;
    const back: Deltas = {};
    for (const k of keysOf(e.deltas)) back[k] = -e.deltas[k]!;
    const rid = this.newId('e');
    const reversing: RelationshipEvent = {
      id: rid,
      kindId: 'undo',
      category: 'correction',
      title: `Undid: ${e.title}`,
      at: o.now,
      why: o.reason ?? 'You reversed this change. The values went back; the moment itself still happened in the story.',
      source: 'undo',
      deltas: back,
      multipliers: {},
      evidence: null,
      chatTitle: 'Relationship journal',
      conversationId: null,
      messageId: null,
      turn: r.turn,
      stageBefore: null,
      stageAfter: null,
      undoable: false,
      undoneBy: null,
      undoOf: e.id,
      fromDeletedChat: false,
    };
    let next: Relationship = {
      ...r,
      values: plusValues(r.values, back),
      events: [reversing, ...r.events.map((x) => (x.id === e.id ? { ...x, undoneBy: rid } : x))],
      ledger: r.ledger.filter((l) => l.eventId !== e.id),
    };
    const idx = stageFor(next);
    if (idx !== next.stageIdx) {
      const before = next.stageIdx;
      next = { ...next, stageIdx: idx };
      next = { ...next, events: [this.stageEntry(next, before, 'undo', o.now, 'Relationship journal', null), ...next.events] };
    }
    return next;
  }

  /** Your correction: the new values become the baseline. */
  applyCorrection(r: Relationship, target: Values, o: { now: Date; reason?: string | null }): Relationship {
    const deltas: Deltas = {};
    let values = r.values;
    for (const k of REL_VALUES) {
      const t = clamp(target[k], 0, 100);
      const d = roundHalf(t - r.values[k]);
      if (d !== 0) deltas[k] = d;
      values = { ...values, [k]: t };
    }
    if (Object.keys(deltas).length === 0) return r;
    const reason = o.reason?.trim() ?? '';
    const event: RelationshipEvent = {
      id: this.newId('e'),
      kindId: 'correction',
      category: 'correction',
      title: reason === '' ? 'Adjusted by you' : reason,
      at: o.now,
      why: 'Manual correction. These values are the new baseline, and the next reply is written with them.',
      source: 'user',
      deltas,
      multipliers: {},
      evidence: null,
      chatTitle: 'Relationship journal',
      conversationId: null,
      messageId: null,
      turn: r.turn,
      stageBefore: r.stageIdx,
      stageAfter: null,
      undoable: true,
      undoneBy: null,
      undoOf: null,
      fromDeletedChat: false,
    };
    let next: Relationship = { ...r, values, events: [event, ...r.events] };
    const idx = stageFor(next);
    if (idx !== next.stageIdx) {
      const before = next.stageIdx;
      next = { ...next, stageIdx: idx };
      next = { ...next, events: [this.stageEntry(next, before, 'user', o.now, 'Relationship journal', null), ...next.events] };
    }
    return next;
  }

  // ── settings ────────────────────────────────────────────────────────────

  /** Switching to Platonic, Family etc. caps the romantic stages; history is kept. */
  setType(r: Relationship, type: RelationType): Relationship {
    const next = { ...r, type };
    return { ...next, stageIdx: stageFor(next) };
  }

  setPacing(r: Relationship, pacing: RelPacing): Relationship {
    return { ...r, pacing };
  }

  applyPreset(r: Relationship, p: StagePreset): Relationship {
    const next = { ...r, stages: [...p.stages], romanticFrom: p.romanticFrom };
    return { ...next, stageIdx: stageFor(next) };
  }

  /**
   * Starts over from [start]: kind, stage arc and stage, pacing and values all
   * match it, and the stage is unlocked. Earlier moments stay in the timeline.
   * Logged as your correction, without an Undo of its own (it changes more than
   * the values): pick another starting point instead.
   */
  applyStartingPoint(r: Relationship, start: StartingPoint, o: { now: Date }): Relationship {
    const s = STARTING_SETUPS[start];
    const p = presetById(s.presetId);
    const deltas: Deltas = {};
    for (const k of REL_VALUES) {
      const d = roundHalf(s.values[k] - r.values[k]);
      if (d !== 0) deltas[k] = d;
    }
    const unchanged =
      r.startingPoint === start &&
      REL_VALUES.every((k) => r.values[k] === s.values[k]) &&
      r.type === s.type &&
      r.pacing === s.pacing &&
      r.stageIdx === s.stageIdx &&
      !r.stageLocked &&
      r.romanticFrom === p.romanticFrom &&
      r.stages.join('\n') === p.stages.join('\n');
    if (unchanged) return r;
    const event: RelationshipEvent = {
      id: this.newId('e'),
      kindId: 'start',
      category: 'correction',
      title: `Starting point: ${STARTING_LABEL[start]}`,
      at: o.now,
      why:
        'You chose where your story starts. The kind of relationship, the stages, ' +
        'the pacing and the values now match it, and the next reply is written with them. ' +
        'Earlier moments stay in the timeline; to change it again, pick another starting point.',
      source: 'user',
      deltas,
      multipliers: {},
      evidence: null,
      chatTitle: 'Relationship journal',
      conversationId: null,
      messageId: null,
      turn: r.turn,
      stageBefore: null,
      stageAfter: null,
      undoable: false,
      undoneBy: null,
      undoOf: null,
      fromDeletedChat: false,
    };
    return {
      ...r,
      startingPoint: start,
      type: s.type,
      pacing: s.pacing,
      values: { ...s.values },
      stages: [...p.stages],
      romanticFrom: p.romanticFrom,
      stageIdx: s.stageIdx,
      stageLocked: false,
      events: [event, ...r.events],
    };
  }

  /** Edit stage names, set the current stage yourself, and lock it. */
  saveStages(r: Relationship, names: string[], current: number, lock: boolean, o: { now: Date }): Relationship {
    const cleaned = r.stages.map((s, i) => (i < names.length && names[i].trim() !== '' ? names[i].trim() : s));
    let next: Relationship = {
      ...r,
      stages: cleaned,
      stageIdx: clamp(current, 0, cleaned.length - 1),
      stageLocked: lock,
    };
    if (current !== r.stageIdx) {
      const event: RelationshipEvent = {
        id: this.newId('e'),
        kindId: null,
        category: 'correction',
        title: `Stage set to ${cleaned[next.stageIdx]}`,
        at: o.now,
        why:
          'You set the stage yourself.' +
          (lock ? ' It’s locked, so the engine won’t move it.' : ' The engine may move it again as the story continues.'),
        source: 'user',
        deltas: {},
        multipliers: {},
        evidence: null,
        chatTitle: 'Relationship journal',
        conversationId: null,
        messageId: null,
        turn: r.turn,
        stageBefore: null,
        stageAfter: null,
        undoable: false,
        undoneBy: null,
        undoOf: null,
        fromDeletedChat: false,
      };
      next = { ...next, events: [event, ...next.events] };
    }
    return next;
  }

  addFact(r: Relationship, text: string, o: { locked?: boolean; tags?: string[] } = {}): Relationship {
    const t = text.trim();
    if (t === '') return r;
    const f: Fact = { id: this.newId('f'), text: t, locked: o.locked ?? true, tags: o.tags ?? inferFactTags(t) };
    return { ...r, facts: [...r.facts, f] };
  }

  setFactLocked(r: Relationship, id: string, locked: boolean): Relationship {
    return { ...r, facts: r.facts.map((f) => (f.id === id ? { ...f, locked } : f)) };
  }

  removeFact(r: Relationship, id: string): Relationship {
    return { ...r, facts: r.facts.filter((f) => f.id !== id) };
  }

  /** Marks every event from a deleted conversation (they stay in the timeline). */
  markChatDeleted(r: Relationship, conversationId: string): Relationship {
    return {
      ...r,
      events: r.events.map((e) => (e.conversationId === conversationId ? { ...e, fromDeletedChat: true } : e)),
    };
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  /** A stage milestone entry. [before] is the old stage index. */
  private stageEntry(
    r: Relationship,
    before: number,
    source: EventSource,
    now: Date,
    chat: string,
    conversationId: string | null,
  ): RelationshipEvent {
    return {
      id: this.newId('e'),
      kindId: null,
      category: 'milestone',
      title: `Stage: ${stageName(r)}`,
      at: now,
      why:
        'Trust and affection, minus tension, crossed this stage’s threshold. ' +
        'Stages only drop after a clear fall, so one bad moment won’t undo a stage.',
      source,
      deltas: {},
      multipliers: {},
      evidence: null,
      chatTitle: chat,
      conversationId,
      messageId: null,
      turn: r.turn,
      stageBefore: before,
      stageAfter: r.stageIdx,
      undoable: false,
      undoneBy: null,
      undoOf: null,
      fromDeletedChat: false,
    };
  }
}

const countIgnored = (r: Relationship): Relationship => ({ ...r, ignored: r.ignored + 1 });

const ignored = (r: Relationship, reason: IgnoreReason, counted: boolean): EngineOutcome => ({
  kind: 'ignored',
  relationship: r,
  reason,
  counted,
});

export { STAGE_PRESETS };
export type { LedgerEntry };
