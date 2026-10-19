// The server-side event catalogue (RELATIONSHIP_ENGINE.md) and the user-text
// classifier. Port of lib/features/relationship/domain/event_catalogue.dart.
import type { Deltas, TimelineKind } from './models.ts';

export interface EventKind {
  id: string;
  /** How the timeline names it when the user did it. */
  userLabel: string;
  category: TimelineKind;
  deltas: Deltas;
  /** Counts at most once per [cooldown] user turns. */
  cooldown: number;
  /** Tags of locked facts this kind would contradict. */
  contradicts: string[];
  /** Another kind that must have counted before (promise_kept → promise_made). */
  needsEarlier?: string;
  /** Only counts when tension is above this. */
  minTension?: number;
  /** Only when the relationship type allows romance. */
  romanceOnly: boolean;
  /** Usually the character's own action (proposed by the model). */
  characterSide: boolean;
}

function kind(
  id: string,
  userLabel: string,
  category: TimelineKind,
  deltas: Deltas,
  o: Partial<EventKind> = {},
): EventKind {
  return {
    id,
    userLabel,
    category,
    deltas,
    cooldown: 6,
    contradicts: [],
    romanceOnly: false,
    characterSide: false,
    ...o,
  };
}

// Key order inside `deltas` matters: the first entry leads the pacing note.
export const EVENT_CATALOGUE: Record<string, EventKind> = {
  promise_made: kind('promise_made', 'You made a promise', 'shift', { trust: 4 }),
  promise_kept: kind('promise_kept', 'You kept your word', 'milestone', { trust: 6 }, {
    needsEarlier: 'promise_made',
  }),
  promise_broken: kind('promise_broken', 'You broke a promise', 'setback', { trust: -8, tension: 6 }, {
    contradicts: ['keeps-promises'],
  }),
  help_offered: kind('help_offered', 'You offered help', 'shift', { trust: 3, affection: 1 }),
  rescue: kind('rescue', 'You came to the rescue', 'milestone', { trust: 6, affection: 3 }),
  boundary_respected: kind('boundary_respected', 'You respected a boundary', 'shift', {
    trust: 3,
    tension: -1,
  }),
  boundary_crossed: kind('boundary_crossed', 'You pushed past a boundary', 'setback', {
    trust: -3,
    tension: 5,
  }),
  vulnerability_shared: kind('vulnerability_shared', 'You opened up', 'shift', { trust: 3, affection: 2 }, {
    characterSide: true,
  }),
  conflict: kind('conflict', 'You said something cruel', 'setback', { tension: 4 }),
  apology: kind('apology', 'You apologised or told the truth', 'reconcile', { tension: -4, trust: 2 }, {
    minTension: 10,
  }),
  reconciliation: kind('reconciliation', 'You made things right', 'reconcile', { tension: -4, trust: 2 }, {
    minTension: 10,
  }),
  betrayal: kind('betrayal', 'A betrayal', 'setback', { trust: -12, affection: -4, tension: 10 }, {
    contradicts: ['loyal'],
    characterSide: true,
  }),
  appreciation: kind('appreciation', 'You showed appreciation', 'shift', { affection: 1 }, {
    cooldown: 10,
  }),
  romantic_gesture: kind('romantic_gesture', 'A romantic gesture', 'shift', { attraction: 2 }, {
    romanceOnly: true,
    contradicts: ['family', 'platonic-only'],
  }),
};

/** First match wins; order matters. Mirrors the Dart rule list exactly. */
const RULES: ReadonlyArray<readonly [string, RegExp]> = [
  ['promise_kept', /\b(i kept (my|the) (promise|word)|as promised|a promise kept)\b/i],
  ['promise_broken', /\b(i broke (my|the|our) (promise|word)|i lied to you)\b/i],
  ['promise_made', /\b(promise|i swear|you have my word|i won't tell|keep (it|your) secret)\b/i],
  ['rescue', /\b(i'll (save|rescue|pull) you|i pulled you out|grab my hand)\b/i],
  ['help_offered', /\b(let me help|i'll help|hold the lamp|i'll stay|protect you|i've got you|together)\b/i],
  ['boundary_respected', /\b(take your time|no pressure|i won't push|i'll wait|you don't have to (tell|say))\b/i],
  ['boundary_crossed', /\b(open it anyway|just tell me|why won't you|read it without|go through your)\b/i],
  ['apology', /\b(i'm sorry|i apologi[sz]e|i was wrong|the truth is|forgive me)\b/i],
  ['appreciation', /\b(thank you|thanks|that was kind|i'm glad you)\b/i],
  ['conflict', /\b(liar|coward|shut up|pathetic|useless)\b/i],
  ['romantic_gesture', /\b(beautiful|kiss|handsome|pretty|hold your hand)\b/i],
];

/** Phone keyboards type ’ for '; the rules are written with '. */
const straighten = (s: string): string => s.replace(/[‘’ʼ]/g, "'");

/** The kind this message looks like, or null. */
export function classifyUserText(text: string): string | null {
  const t = straighten(text);
  for (const [id, re] of RULES) {
    if (re.test(t)) return id;
  }
  return null;
}
