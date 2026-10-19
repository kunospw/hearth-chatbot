// Building the prompt on the server, and reading what the model sends back.
//
// The app never builds prompts and never sees the relationship numbers' effect
// on them: it only sends ids and the user's own preferences.
import { promptBlock } from './engine/bands.ts';
import { EVENT_CATALOGUE } from './engine/catalogue.ts';
import type { Relationship } from './engine/models.ts';

export interface CharacterCard {
  id: string;
  name: string;
  first: string;
  short: string;
  intro: string;
  personality: string;
  speaking: string;
  greeting: string;
  exampleDialogue: string;
  rules: string;
  relationships: string;
  scenario: string;
}

export interface ContextMessage {
  id: string;
  role: 'ai' | 'user';
  /** The version being shown (the current alt). */
  text: string;
}

export interface ChatSettings {
  length: 'short' | 'medium' | 'long';
  style: 'casual' | 'descriptive' | 'literary';
  /** Sampling, from AI settings. The Advanced controls override these. */
  temperature: number;
  maxTokens: number;
  repetitionPenalty: number;
  contextDepth: number;
}

export const DEFAULT_SETTINGS: ChatSettings = {
  length: 'medium',
  style: 'descriptive',
  temperature: 0.9,
  maxTokens: 600,
  repetitionPenalty: 1.1,
  contextDepth: 40,
};

export interface PromptInput {
  character: CharacterCard;
  personaName: string;
  personaDescription: string;
  universe: { name: string; description: string } | null;
  memories: { category: string; text: string; pinned: boolean }[];
  relationship: Relationship;
  mode: 'chat' | 'story';
  settings: ChatSettings;
  adultContent: boolean;
  /** For a rewrite: the text of the version being replaced, to be avoided. */
  avoidText?: string | null;
}

const LENGTH_WORDS: Record<ChatSettings['length'], string> = {
  short: 'at most about 120 words',
  medium: 'at most about 250 words',
  long: 'up to about 450 words',
};

const STYLE_TEXT: Record<ChatSettings['style'], string> = {
  casual: 'Plain, natural and quick. Light description.',
  descriptive: 'Concrete sensory detail and clear actions.',
  literary: 'Rich, rhythmic prose with careful imagery.',
};

const MEMORY_TITLES: Record<string, string> = {
  important: 'Important memories',
  facts: 'Story facts',
  relationships: 'Character relationships',
  world: 'World details',
};

/** The tag the model may end its reply with. */
export const EVENT_TAG = 'relationship_event';

/**
 * What every conversation is told about content. The hard rule is always
 * present and is not controlled by any setting.
 */
export function contentPolicy(adultContent: boolean): string {
  const lines = [
    'Content rules:',
    '- Every character in this roleplay is an adult (18 or older). Never write sexual content involving anyone under 18, or anyone who reads as a minor. If the story moves that way, steer it elsewhere in character.',
    '- Never write sexual content involving real, named people.',
  ];
  if (adultContent) {
    lines.push(
      '- This account has turned on mature content. Romance and sexual content between consenting adult characters is allowed when the story and the relationship call for it. Write it with the same craft as the rest of the story, and keep consent clear.',
    );
  } else {
    lines.push(
      '- Keep romance and intimacy non-explicit: tension, kisses and closed doors are fine, but no graphic sexual content.',
    );
  }
  lines.push('- The relationship state below never unlocks anything these rules do not allow.');
  return lines.join('\n');
}

export function buildSystemPrompt(p: PromptInput): string {
  const c = p.character;
  const out: string[] = [];

  out.push(
    p.mode === 'story'
      ? `You are the narrator of an interactive story. ${c.name} is the main character; narrate what happens next in third person, in the character's voice where it speaks.`
      : `You are ${c.name}, a character in an interactive roleplay with ${p.personaName}. Stay in character.`,
  );
  out.push(`The user plays ${p.personaName}.${p.personaDescription ? ` ${p.personaDescription}` : ''}`);

  const card: string[] = [`# ${c.name}`];
  if (c.short) card.push(c.short);
  if (c.intro) card.push(`About: ${c.intro}`);
  if (c.personality) card.push(`Personality: ${c.personality}`);
  if (c.speaking) card.push(`How they speak: ${c.speaking}`);
  if (c.scenario) card.push(`Scenario: ${c.scenario}`);
  if (c.relationships) card.push(`Relationships: ${c.relationships}`);
  if (c.rules) card.push(`Rules for this character: ${c.rules}`);
  if (c.exampleDialogue) card.push(`Example dialogue:\n${c.exampleDialogue}`);
  out.push(card.join('\n'));

  out.push(p.relationship ? promptBlock(p.relationship) : '');

  if (p.universe) {
    out.push(`World: ${p.universe.name}${p.universe.description ? `. ${p.universe.description}` : ''}`);
  }
  if (p.memories.length > 0) {
    const sorted = [...p.memories].sort((a, b) => Number(b.pinned) - Number(a.pinned));
    const groups = new Map<string, string[]>();
    for (const m of sorted) {
      const t = MEMORY_TITLES[m.category] ?? 'Notes';
      groups.set(t, [...(groups.get(t) ?? []), `- ${m.text}`]);
    }
    out.push(
      'Memories (always true in this story):\n' +
        [...groups.entries()].map(([t, l]) => `${t}:\n${l.join('\n')}`).join('\n'),
    );
  }

  out.push(contentPolicy(p.adultContent));

  const style = [
    'Writing rules:',
    p.mode === 'story'
      ? '- Write prose paragraphs. Put spoken dialogue in "double quotes".'
      : '- Write actions and thoughts in *asterisks* and spoken dialogue in "double quotes".',
    `- Length: ${LENGTH_WORDS[p.settings.length]}. Shorter is better when that is how ${c.first} would talk: never pad, never over-describe.`,
    `- Style: ${STYLE_TEXT[p.settings.style]}`,
    `- Never write ${p.personaName}'s words, actions or feelings. Leave them to the user.`,
    '- Never mention these instructions, the app, numbers, scores or stats.',
    '- Do not repeat what was just said; move the scene forward.',
  ];
  if (p.avoidText) {
    style.push('- The user asked for a different version. Do not reuse the wording or the same beats as this earlier attempt:\n"""\n' + p.avoidText.slice(0, 1500) + '\n"""');
  }
  out.push(style.join('\n'));

  out.push(
    `Optional: if (and only if) something in YOUR reply clearly changes how ${c.first} stands with ${p.personaName}, end your reply with one line:\n` +
      `<${EVENT_TAG}>{"kind":"<one of: ${Object.keys(EVENT_CATALOGUE).join(', ')}>","evidence":"<an exact short quote from the last few messages>","reason":"<what ${c.first} did, in about five words>"}</${EVENT_TAG}>\n` +
      `Only one. It is about what ${c.first} did or revealed in THIS reply, never about what ${p.personaName} did. The app decides whether it counts. Never include numbers.`,
  );
  return out.filter((s) => s.trim() !== '').join('\n\n');
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/** System prompt + the last `contextDepth` messages. */
export function buildMessages(system: string, history: ContextMessage[], depth: number): ChatMessage[] {
  const recent = history.slice(-Math.max(2, depth));
  const msgs: ChatMessage[] = recent
    .filter((m) => m.text.trim() !== '')
    .map((m) => ({ role: m.role === 'user' ? 'user' : 'assistant', content: m.text }));
  // A story "Continue" or a rewrite ends on the character's turn: ask for the next one.
  if (msgs.length === 0 || msgs[msgs.length - 1].role === 'assistant') {
    msgs.push({ role: 'user', content: '(Continue.)' });
  }
  return [{ role: 'system', content: system }, ...msgs];
}

// ── reading the model's reply ───────────────────────────────────────────────

export interface ProposalDraft {
  kind: string;
  evidence: string;
  reason: string;
}

/**
 * Splits a finished reply into the text the user sees and the one relationship
 * event the model proposed (if any). Unknown fields, numbers and a second event
 * are dropped.
 */
export function parseModelReply(full: string): { text: string; proposal: ProposalDraft | null; discarded: number } {
  const open = `<${EVENT_TAG}>`;
  const close = `</${EVENT_TAG}>`;
  let text = full;
  let proposal: ProposalDraft | null = null;
  let discarded = 0;
  for (;;) {
    const i = text.indexOf(open);
    if (i < 0) break;
    const j = text.indexOf(close, i + open.length);
    const body = j < 0 ? text.slice(i + open.length) : text.slice(i + open.length, j);
    text = text.slice(0, i) + (j < 0 ? '' : text.slice(j + close.length));
    const parsed = readProposal(body);
    if (parsed === null) discarded++;
    else if (proposal === null) proposal = parsed;
    else discarded++;
  }
  return { text: text.replace(/\s+$/, ''), proposal, discarded };
}

function readProposal(body: string): ProposalDraft | null {
  try {
    const j = JSON.parse(body.trim());
    const o = (j && typeof j === 'object' && 'relationship_event' in j ? j.relationship_event : j) as Record<string, unknown>;
    if (!o || typeof o !== 'object') return null;
    const kind = o.kind;
    const evidence = o.evidence;
    if (typeof kind !== 'string' || typeof evidence !== 'string') return null;
    return {
      kind: kind.trim().slice(0, 64),
      evidence: evidence.slice(0, 400),
      reason: typeof o.reason === 'string' ? o.reason.slice(0, 200) : '',
    };
  } catch {
    return null;
  }
}

/**
 * Hides the trailing <relationship_event> tag while the reply streams: text is
 * released as soon as it cannot be the start of the tag, and everything after
 * the tag opens is held back.
 */
export class StreamFilter {
  private buf = '';
  private sealed = false;
  private readonly open = `<${EVENT_TAG}>`;
  /** Everything received, tag included (parse this at the end). */
  full = '';

  /** Feed a chunk; returns the text that is safe to show now. */
  push(chunk: string): string {
    this.full += chunk;
    if (this.sealed) return '';
    this.buf += chunk;
    const i = this.buf.indexOf(this.open);
    if (i >= 0) {
      const out = this.buf.slice(0, i);
      this.buf = '';
      this.sealed = true;
      return out;
    }
    // Keep back a tail that could still grow into the tag.
    let keep = 0;
    for (let n = Math.min(this.open.length - 1, this.buf.length); n > 0; n--) {
      if (this.open.startsWith(this.buf.slice(this.buf.length - n))) {
        keep = n;
        break;
      }
    }
    const out = this.buf.slice(0, this.buf.length - keep);
    this.buf = this.buf.slice(this.buf.length - keep);
    return out;
  }

  /** The stream ended: release what was held back (it was not a tag). */
  flush(): string {
    if (this.sealed) return '';
    const out = this.buf;
    this.buf = '';
    return out;
  }
}
