// An in-memory Store for handler tests. commit() applies a patch the way
// commit_relationship() does in SQL (that SQL is tested against the engine in
// db_roundtrip.test.ts), and keeps one user's world.
import { deriveLedger, type Relationship, type RelationshipEvent, type Suggestion } from '../../functions/_shared/engine/models.ts';
import { eventFromJson, suggestionFromJson } from '../../functions/_shared/engine/models.ts';
import type { RelationshipPatch } from '../../functions/_shared/engine/persist.ts';
import {
  NotFoundError,
  VersionConflictError,
  type ChatContext,
  type ConsumeResult,
  type Store,
  type StoredProposal,
  type ThreadMessage,
} from '../../functions/_shared/store.ts';

export const DEFAULT_STAGES = ['Strangers', 'Acquaintances', 'Allies', 'Friends', 'Close Friends', 'Found Family'];

export function newRelationship(id: string, characterId: string, personaId: string): Relationship {
  return {
    id,
    characterId,
    personaId,
    universeId: null,
    type: 'undecided',
    pacing: 'balanced',
    values: { trust: 20, affection: 15, attraction: 0, tension: 0 },
    stages: [...DEFAULT_STAGES],
    stageIdx: 1,
    stageLocked: false,
    romanticFrom: null,
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

export function applyPatch(r: Relationship, p: RelationshipPatch): Relationship {
  let n: Relationship = { ...r, version: r.version + 1 };
  if (p.type !== undefined) n.type = p.type as Relationship['type'];
  if (p.pacing !== undefined) n.pacing = p.pacing as Relationship['pacing'];
  if (p.values !== undefined) n.values = { ...p.values };
  if (p.stageIdx !== undefined) n.stageIdx = p.stageIdx;
  if (p.stageLocked !== undefined) n.stageLocked = p.stageLocked;
  if ('romanticFrom' in p) n.romanticFrom = p.romanticFrom ?? null;
  if (p.turn !== undefined) n.turn = p.turn;
  if (p.ignored !== undefined) n.ignored = p.ignored;
  if (p.recentHashes !== undefined) n.recentHashes = p.recentHashes;
  if (p.stages !== undefined) n.stages = p.stages;
  if (p.facts?.delete) n.facts = n.facts.filter((f) => !p.facts!.delete!.includes(f.id));
  for (const f of (p.facts?.upsert ?? []) as Relationship['facts']) {
    const i = n.facts.findIndex((x) => x.id === f.id);
    n.facts = i < 0 ? [...n.facts, { ...f }] : n.facts.map((x) => (x.id === f.id ? { ...f } : x));
  }
  let events: RelationshipEvent[] = n.events;
  for (const ej of (p.events?.insert ?? []) as Record<string, unknown>[]) {
    const e = eventFromJson(ej);
    events = [e, ...events];
    if (e.undoOf !== null) events = events.map((x) => (x.id === e.undoOf ? { ...x, undoneBy: e.id } : x));
  }
  n.events = events;
  if (p.suggestions?.delete) n.pending = n.pending.filter((s) => !p.suggestions!.delete!.includes(s.id));
  for (const sj of (p.suggestions?.insert ?? []) as Record<string, unknown>[]) {
    n.pending = [suggestionFromJson(sj) as Suggestion, ...n.pending];
  }
  n.ledger = deriveLedger(n.events, n.pending);
  return n;
}

export class FakeStore implements Store {
  /** What the one test user owns. */
  readonly userId = '11111111-1111-4111-8111-111111111111';
  ctx: ChatContext;
  relationships = new Map<string, Relationship>();
  proposals = new Map<string, StoredProposal>();
  /** Daily free replies left per model (null = unlimited), and which are busy. */
  replies = new Map<string, { left: number | null; busy?: boolean; ollamaModel: string }>();
  refunds = 0;
  consumed = 0;
  /** Make the next N commits fail with a version conflict. */
  conflicts = 0;
  commits = 0;

  constructor(ctx: ChatContext) {
    this.ctx = ctx;
    this.replies.set('ember', { left: 30, ollamaModel: 'test-model' });
  }

  private mine(userId: string): boolean {
    return userId === this.userId;
  }

  async loadContext(userId: string, conversationId: string, personaId: string): Promise<ChatContext | null> {
    if (!this.mine(userId) || conversationId !== this.ctx.conversation.id || personaId !== this.ctx.persona.id) return null;
    return structuredClone(this.ctx);
  }

  async ensureRelationship(userId: string, characterId: string, personaId: string): Promise<Relationship> {
    if (!this.mine(userId) || characterId !== this.ctx.character.id || personaId !== this.ctx.persona.id) {
      throw new NotFoundError('character or persona');
    }
    const key = `${characterId}:${personaId}`;
    let r = [...this.relationships.values()].find((x) => `${x.characterId}:${x.personaId}` === key);
    if (!r) {
      r = newRelationship('22222222-2222-4222-8222-222222222222', characterId, personaId);
      this.relationships.set(r.id, r);
    }
    return structuredClone(r);
  }

  async loadRelationship(userId: string, relationshipId: string): Promise<Relationship | null> {
    const r = this.mine(userId) ? this.relationships.get(relationshipId) : undefined;
    return r ? structuredClone(r) : null;
  }

  async commit(userId: string, rel: Relationship, patch: RelationshipPatch): Promise<Relationship> {
    const cur = this.relationships.get(rel.id);
    if (!this.mine(userId) || !cur) throw new NotFoundError('relationship');
    this.commits++;
    if (this.conflicts > 0) {
      this.conflicts--;
      throw new VersionConflictError();
    }
    if (cur.version !== rel.version) throw new VersionConflictError();
    const next = applyPatch(cur, patch);
    this.relationships.set(next.id, next);
    return structuredClone(next);
  }

  async loadMessage(userId: string, messageId: string) {
    const m = this.mine(userId) ? this.ctx.messages.find((x) => x.id === messageId) : undefined;
    return m ? { ...structuredClone(m), conversationId: this.ctx.conversation.id, title: this.ctx.conversation.title } : null;
  }

  async loadThread(userId: string, conversationId: string): Promise<ThreadMessage[]> {
    return this.mine(userId) && conversationId === this.ctx.conversation.id ? structuredClone(this.ctx.messages) : [];
  }

  async conversationCharacter(userId: string, conversationId: string) {
    return this.mine(userId) && conversationId === this.ctx.conversation.id
      ? { characterId: this.ctx.character.id, first: this.ctx.character.first }
      : null;
  }

  async lookupModel(modelId: string): Promise<{ ollamaModel: string; busy: boolean } | null> {
    const m = this.replies.get(modelId);
    return m ? { ollamaModel: m.ollamaModel, busy: m.busy === true } : null;
  }

  async consumeReply(_userId: string, modelId: string): Promise<ConsumeResult> {
    const m = this.replies.get(modelId);
    if (!m) return { ok: false, reason: 'unknown_model' };
    if (m.busy) return { ok: false, reason: 'busy' };
    if (m.left !== null && m.left <= 0) return { ok: false, reason: 'limit', limit: 30 };
    if (m.left !== null) m.left--;
    this.consumed++;
    return { ok: true, ollamaModel: m.ollamaModel, used: this.consumed, limit: 30 };
  }

  async refundReply(_userId: string, modelId: string): Promise<void> {
    const m = this.replies.get(modelId);
    if (m && m.left !== null) m.left++;
    this.refunds++;
  }

  async saveProposal(_userId: string, p: StoredProposal): Promise<void> {
    this.proposals.set(`${p.messageId}:${p.altIndex}`, p);
  }

  async loadProposal(_userId: string, messageId: string, altIndex: number): Promise<StoredProposal | null> {
    return this.proposals.get(`${messageId}:${altIndex}`) ?? null;
  }
}

export const ids = {
  conversation: '33333333-3333-4333-8333-333333333333',
  character: '44444444-4444-4444-8444-444444444444',
  persona: '55555555-5555-4555-8555-555555555555',
  user1: '66666666-6666-4666-8666-666666666601',
  ai1: '66666666-6666-4666-8666-666666666602',
  user2: '66666666-6666-4666-8666-666666666603',
  ai2: '66666666-6666-4666-8666-666666666604',
  aiNew: '66666666-6666-4666-8666-666666666699',
};

export function sampleContext(over: Partial<ChatContext> = {}): ChatContext {
  return {
    conversation: { id: ids.conversation, characterId: ids.character, title: 'The letter', mode: 'chat' },
    character: {
      id: ids.character,
      name: 'Vesper Hale',
      first: 'Vesper',
      short: 'A weary lighthouse keeper',
      intro: 'Keeps the light alone.',
      personality: 'Dry, guarded, observant.',
      speaking: 'Short sentences.',
      greeting: 'The lamp is lit.',
      exampleDialogue: '',
      rules: '',
      relationships: '',
      scenario: 'A storm is coming.',
    },
    persona: { id: ids.persona, name: 'Wren', description: 'A courier.' },
    universe: { id: 'u1', name: 'The Saltmarsh Coast', description: 'Tides and fog.' },
    memories: [
      { category: 'facts', text: 'The bell is cracked.', pinned: false },
      { category: 'important', text: 'Her father died at sea.', pinned: true },
    ],
    messages: [
      { id: ids.ai1, role: 'ai', alts: ['The lamp is lit.'], altIndex: 0 },
      { id: ids.user1, role: 'user', alts: ['I promise I will keep your secret, you have my word.'], altIndex: 0 },
    ],
    adultContent: false,
    ...over,
  };
}
