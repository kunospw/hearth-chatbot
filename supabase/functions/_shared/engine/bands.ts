// Words, behaviour lines, the prompt block and the stage maths. Port of
// lib/features/relationship/domain/relationship_bands.dart. What the journal
// shows and what the model is told come from the same tables.
import {
  PACING,
  RELATION_LABEL,
  REL_LABEL,
  romanceAllowed,
  stageName,
  type RelPacing,
  type RelValue,
  type Relationship,
  type RelationType,
  type StartingPoint,
  type TimelineKind,
  type Values,
} from './models.ts';

export interface StagePreset {
  id: string;
  label: string;
  stages: string[];
  romanticFrom: number | null;
}

export const STAGE_PRESETS: readonly StagePreset[] = [
  {
    id: 'romance',
    label: 'Romance arc',
    stages: ['Strangers', 'Wary Acquaintances', 'Reluctant Allies', 'Growing Trust', 'Unspoken Feelings', 'Established Relationship'],
    romanticFrom: 4,
  },
  {
    id: 'friendship',
    label: 'Friendship',
    stages: ['Strangers', 'Acquaintances', 'Allies', 'Friends', 'Close Friends', 'Found Family'],
    romanticFrom: null,
  },
  {
    id: 'rivalry',
    label: 'Rivalry',
    stages: ['Rivals', 'Grudging Respect', 'Uneasy Truce', 'Reluctant Allies', 'Trusted Rival', 'Partners'],
    romanticFrom: null,
  },
  {
    id: 'family',
    label: 'Family',
    stages: ['Estranged', 'Distant', 'Thawing', 'Reconnecting', 'Close', 'Unbreakable'],
    romanticFrom: null,
  },
  {
    // For a couple who are already together: the stages say how it's going.
    id: 'couple',
    label: 'Couple',
    stages: ['On the Rocks', 'Drifting Apart', 'Mending', 'Steady', 'Happy Together', 'Deeply in Love'],
    romanticFrom: null,
  },
];

export function presetById(id: string): StagePreset {
  const p = STAGE_PRESETS.find((x) => x.id === id);
  if (!p) throw new Error(`unknown preset ${id}`);
  return p;
}

/** What a starting point sets up. The values sit inside the stage's score band. */
export interface StartingSetup {
  presetId: string;
  stageIdx: number;
  type: RelationType;
  pacing: RelPacing;
  values: Values;
  /** What the model is told about your past together (null: a first meeting). */
  history: string | null;
}

/** The same table is in the Dart engine and in ensure_relationship_for() (SQL). */
export const STARTING_SETUPS: Record<StartingPoint, StartingSetup> = {
  strangers: {
    presetId: 'friendship',
    stageIdx: 1,
    type: 'undecided',
    pacing: 'slow',
    values: { trust: 20, affection: 15, attraction: 0, tension: 0 },
    history: null,
  },
  friends: {
    presetId: 'friendship',
    stageIdx: 3,
    type: 'undecided',
    pacing: 'balanced',
    values: { trust: 55, affection: 55, attraction: 0, tension: 0 },
    history: 'already friends before the story began — this is not a first meeting',
  },
  together: {
    presetId: 'couple',
    stageIdx: 4,
    type: 'romantic',
    pacing: 'balanced',
    values: { trust: 70, affection: 75, attraction: 70, tension: 0 },
    history: 'already a couple before the story began — this is not a first meeting',
  },
  family: {
    presetId: 'family',
    stageIdx: 4,
    type: 'familial',
    pacing: 'balanced',
    values: { trust: 65, affection: 70, attraction: 0, tension: 0 },
    history: 'already family before the story began — this is not a first meeting',
  },
  rivals: {
    presetId: 'rivalry',
    stageIdx: 0,
    type: 'rivalrous',
    pacing: 'slow',
    values: { trust: 15, affection: 15, attraction: 0, tension: 45 },
    history: 'already rivals before the story began — this is not a first meeting',
  },
};

/** A new relationship that begins at [start] (no events, no facts yet). */
export function startingRelationship(o: {
  id: string;
  characterId: string;
  personaId: string;
  universeId?: string | null;
  start?: StartingPoint;
}): Relationship {
  const start = o.start ?? 'strangers';
  const s = STARTING_SETUPS[start];
  const p = presetById(s.presetId);
  return {
    id: o.id,
    characterId: o.characterId,
    personaId: o.personaId,
    universeId: o.universeId ?? null,
    startingPoint: start,
    type: s.type,
    pacing: s.pacing,
    values: { ...s.values },
    stages: [...p.stages],
    stageIdx: s.stageIdx,
    stageLocked: false,
    romanticFrom: p.romanticFrom,
    facts: [],
    events: [],
    pending: [],
    ledger: [],
    recentHashes: [],
    turn: 0,
    ignored: 0,
    version: 0,
  };
}

const band = (v: number, cuts: number[], words: string[]): string => {
  for (let i = 0; i < cuts.length; i++) if (v < cuts[i]) return words[i];
  return words[words.length - 1];
};

export function wordFor(k: RelValue, v: number): string {
  switch (k) {
    case 'trust':
      return band(v, [20, 40, 60, 80], ['Wary', 'Cautious', 'Steady', 'Deep', 'Unshakeable']);
    case 'affection':
      return band(v, [20, 40, 60, 80], ['Cool', 'Polite warmth', 'Fond', 'Warm', 'Devoted']);
    case 'attraction':
      return band(v, [20, 40, 60, 80], ['None shown', 'A flicker', 'Noticeable', 'Strong', 'Undeniable']);
    case 'tension':
      return band(v, [15, 35, 60], ['At ease', 'Mild', 'Strained', 'Volatile']);
  }
}

/** The four "how they act right now" lines. */
export function behaviorLines(r: Relationship): string[] {
  const v = r.values;
  const romance = romanceAllowed(r.type);
  return [
    v.trust < 25
      ? 'Keeps answers short and guards anything personal.'
      : v.trust < 50
        ? 'Shares facts and plans, but not feelings. Talks about the past only if asked gently.'
        : v.trust < 75
          ? 'Confides in you and asks your opinion before big decisions.'
          : 'Trusts you with secrets — and with their safety.',
    v.affection < 25
      ? 'Polite, a little cool.'
      : v.affection < 50
        ? 'Shows warmth through small actions more than words.'
        : 'Openly glad to see you; teases you and checks on you.',
    v.tension > 40
      ? 'On edge: likely to argue, test you or pull away.'
      : v.tension > 15
        ? 'Still a little wary after recent friction; avoids sore subjects.'
        : 'At ease in your company.',
    !romance
      ? 'Romance is off the table — affection reads as friendship, family or respect.'
      : v.attraction < 30
        ? 'Shows no romantic interest; fondness stays platonic for now.'
        : v.attraction < 60
          ? 'Small, unspoken signs of attraction — never named aloud.'
          : 'Romantic feelings are present and may be acknowledged.',
  ];
}

/** The block added to the model's prompt every turn. */
export function promptBlock(r: Relationship): string {
  const v = r.values;
  const romance = romanceAllowed(r.type);
  const history = STARTING_SETUPS[r.startingPoint]?.history ?? null;
  // Once feelings "may be acknowledged" (the top attraction band), saying them
  // is no longer a sudden confession, e.g. for a couple.
  const openRomance = romance && v.attraction >= 60;
  const lines: string[] = [
    '[relationship — set by the app, read-only]',
    `stage: ${stageName(r)}${r.stageLocked ? ' (locked by user)' : ''}`,
    `type: ${RELATION_LABEL[r.type]}${r.type === 'undecided' ? ' — do not assume romance' : romance ? '' : ' — no romance'}`,
    ...(history === null ? [] : [`history: ${history}`]),
    `trust ${Math.round(v.trust)} (${wordFor('trust', v.trust).toLowerCase()}), ` +
      `affection ${Math.round(v.affection)} (${wordFor('affection', v.affection).toLowerCase()}), ` +
      `attraction ${romance ? Math.round(v.attraction) : 'n/a'}, ` +
      `tension ${Math.round(v.tension)} (${wordFor('tension', v.tension).toLowerCase()})`,
    `pacing: ${PACING[r.pacing].label.toLowerCase()} — change openness gradually${openRomance ? '' : '; no sudden confessions'}`,
    'play it like this:',
    ...behaviorLines(r).map((l) => `- ${l}`),
  ];
  const locked = r.facts.filter((f) => f.locked);
  if (locked.length > 0) {
    lines.push('never contradict:');
    for (const f of locked) lines.push(`- ${f.text}`);
  }
  const turning = r.events.filter((e) => e.category !== 'correction' && e.undoneBy === null);
  if (turning.length > 0) lines.push(`latest turning point: ${turning[0].title}`);
  lines.push('you may propose ONE relationship_event {kind, reason}; the app decides whether it counts.');
  return lines.join('\n');
}

export const STAGE_THRESHOLDS: readonly number[] = [-1000, 15, 32, 46, 60, 75];

/** 0.6·trust + 0.4·affection − 0.3·tension. */
export const stageScore = (v: Values): number => v.trust * 0.6 + v.affection * 0.4 - v.tension * 0.3;

export const romanceGateClosed = (r: Relationship): boolean =>
  r.romanticFrom !== null && !(romanceAllowed(r.type) && r.values.attraction >= 35);

/** The stage these values map to, with hysteresis, the romance gate and the lock. */
export function stageFor(r: Relationship): number {
  if (r.stageLocked) return r.stageIdx;
  const last = r.stages.length - 1;
  const score = stageScore(r.values);
  let idx = 0;
  for (let i = 0; i < STAGE_THRESHOLDS.length; i++) {
    if (score >= STAGE_THRESHOLDS[i]) idx = i;
  }
  idx = Math.min(Math.max(idx, 0), last);
  const cap = r.romanticFrom !== null && romanceGateClosed(r) ? r.romanticFrom - 1 : last;
  if (idx > cap) idx = cap;
  // Hysteresis: hold the current stage until the score is clearly below it.
  const cur = Math.min(Math.max(r.stageIdx, 0), last);
  if (idx < cur && cur <= cap && score >= STAGE_THRESHOLDS[cur] - 5) idx = cur;
  return Math.min(Math.max(idx, 0), last);
}

/** "+4" / "−3" with a real minus sign. */
export function signed(v: number): string {
  const a = Math.abs(v);
  const n = a === Math.round(a) ? a.toFixed(0) : a.toFixed(1);
  return `${v > 0 ? '+' : '−'}${n}`;
}

export { REL_LABEL };
export type { TimelineKind };
