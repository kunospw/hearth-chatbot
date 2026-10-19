// The real Store: supabase-js with the SERVICE ROLE key. The service role
// bypasses RLS, so every query here filters by the verified user id itself.
// Deno-only (npm: specifier); everything else in _shared runs on Node too.
import { relationshipFromJson, type Relationship } from './engine/models.ts';
import type { RelationshipPatch } from './engine/persist.ts';
import {
  NotFoundError,
  VersionConflictError,
  type ChatContext,
  type ConsumeResult,
  type Store,
  type StoredProposal,
  type ThreadMessage,
} from './store.ts';

// A structural slice of SupabaseClient, so this file type-checks without importing it.
interface Query extends PromiseLike<{ data: any; error: { message: string; code?: string } | null }> {
  select(columns?: string): Query;
  eq(column: string, value: unknown): Query;
  order(column: string, o?: { ascending?: boolean }): Query;
  maybeSingle(): Query;
  single(): Query;
  upsert(row: unknown, o?: { onConflict?: string }): Query;
}
export interface Admin {
  from(table: string): Query;
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<{ data: any; error: { message: string; code?: string } | null }>;
}

function check<T>(r: { data: T; error: { message: string } | null }, what: string): T {
  if (r.error) throw new Error(`${what}: ${r.error.message}`);
  return r.data;
}

const toThread = (m: any): ThreadMessage => ({
  id: m.id,
  role: m.role,
  alts: Array.isArray(m.alts) ? m.alts.map(String) : [],
  altIndex: m.alt_index ?? 0,
});

export class SupabaseStore implements Store {
  private readonly db: Admin;
  constructor(db: Admin) {
    this.db = db;
  }

  async loadContext(userId: string, conversationId: string, personaId: string): Promise<ChatContext | null> {
    const db = this.db;
    const conv = check(
      await db.from('conversations').select('id,character_id,title,mode').eq('id', conversationId).eq('user_id', userId).maybeSingle(),
      'conversation',
    );
    if (!conv) return null;
    const ch = check(await db.from('characters').select('*').eq('id', conv.character_id).eq('user_id', userId).maybeSingle(), 'character');
    const persona = check(
      await db.from('personas').select('id,name,description').eq('id', personaId).eq('user_id', userId).maybeSingle(),
      'persona',
    );
    if (!ch || !persona) return null;

    const uni = ch.universe_id
      ? check(await db.from('universes').select('id,name,description').eq('id', ch.universe_id).eq('user_id', userId).maybeSingle(), 'universe')
      : null;
    const memories = uni
      ? check(await db.from('memories').select('category,text,pinned').eq('universe_id', uni.id).eq('user_id', userId).order('pos'), 'memories')
      : [];
    const messages = check(
      await db.from('messages').select('id,role,alts,alt_index').eq('conversation_id', conversationId).eq('user_id', userId).order('seq'),
      'messages',
    );
    const profile = check(await db.from('profiles').select('adult_content').eq('id', userId).maybeSingle(), 'profile');

    return {
      conversation: { id: conv.id, characterId: conv.character_id, title: conv.title, mode: conv.mode },
      character: {
        id: ch.id,
        name: ch.name,
        first: ch.first,
        short: ch.short,
        intro: ch.intro,
        personality: ch.personality,
        speaking: ch.speaking,
        greeting: ch.greeting,
        exampleDialogue: ch.example_dialogue,
        rules: ch.rules,
        relationships: ch.relationships,
        scenario: ch.scenario,
      },
      persona: { id: persona.id, name: persona.name, description: persona.description },
      universe: uni ? { id: uni.id, name: uni.name, description: uni.description } : null,
      memories: memories.map((m: any) => ({ category: m.category, text: m.text, pinned: m.pinned })),
      messages: messages.map(toThread),
      adultContent: profile?.adult_content === true,
    };
  }

  async ensureRelationship(userId: string, characterId: string, personaId: string): Promise<Relationship> {
    const r = await this.db.rpc('ensure_relationship_for', { p_user: userId, p_character: characterId, p_persona: personaId });
    if (r.error) {
      if (r.error.message.includes('not_found')) throw new NotFoundError('character or persona');
      throw new Error(`ensure_relationship: ${r.error.message}`);
    }
    return relationshipFromJson(r.data);
  }

  async loadRelationship(userId: string, relationshipId: string): Promise<Relationship | null> {
    const snap = check(await this.db.rpc('relationship_snapshot_for', { p_id: relationshipId, p_user: userId }), 'snapshot');
    return snap ? relationshipFromJson(snap) : null;
  }

  async commit(userId: string, rel: Relationship, patch: RelationshipPatch): Promise<Relationship> {
    const r = await this.db.rpc('commit_relationship', {
      p_id: rel.id,
      p_user: userId,
      p_expected_version: rel.version,
      p_patch: patch,
    });
    if (r.error) {
      if (r.error.message.includes('version_conflict')) throw new VersionConflictError();
      throw new Error(`commit_relationship: ${r.error.message}`);
    }
    return relationshipFromJson(r.data);
  }

  async loadMessage(userId: string, messageId: string) {
    const m = check(
      await this.db.from('messages').select('id,role,alts,alt_index,conversation_id').eq('id', messageId).eq('user_id', userId).maybeSingle(),
      'message',
    );
    if (!m) return null;
    const c = check(
      await this.db.from('conversations').select('title').eq('id', m.conversation_id).eq('user_id', userId).maybeSingle(),
      'conversation',
    );
    return { ...toThread(m), conversationId: m.conversation_id as string, title: (c?.title ?? 'Story') as string };
  }

  async loadThread(userId: string, conversationId: string): Promise<ThreadMessage[]> {
    const rows = check(
      await this.db.from('messages').select('id,role,alts,alt_index').eq('conversation_id', conversationId).eq('user_id', userId).order('seq'),
      'thread',
    );
    return rows.map(toThread);
  }

  async conversationCharacter(userId: string, conversationId: string) {
    const c = check(
      await this.db.from('conversations').select('character_id').eq('id', conversationId).eq('user_id', userId).maybeSingle(),
      'conversation',
    );
    if (!c) return null;
    const ch = check(await this.db.from('characters').select('first').eq('id', c.character_id).eq('user_id', userId).maybeSingle(), 'character');
    return ch ? { characterId: c.character_id as string, first: ch.first as string } : null;
  }

  async lookupModel(modelId: string): Promise<{ ollamaModel: string; busy: boolean } | null> {
    const m = check(
      await this.db.from('models').select('ollama_model,enabled,busy').eq('id', modelId).maybeSingle(),
      'model',
    );
    return m && m.enabled ? { ollamaModel: m.ollama_model as string, busy: m.busy === true } : null;
  }

  async consumeReply(userId: string, modelId: string): Promise<ConsumeResult> {
    const d = check(await this.db.rpc('consume_model_reply', { p_user: userId, p_model: modelId }), 'consume');
    if (d.ok) return { ok: true, ollamaModel: d.ollamaModel, used: d.used, limit: d.limit ?? null };
    return { ok: false, reason: d.reason, limit: d.limit ?? null };
  }

  async refundReply(userId: string, modelId: string): Promise<void> {
    check(await this.db.rpc('refund_model_reply', { p_user: userId, p_model: modelId }), 'refund');
  }

  async saveProposal(userId: string, p: StoredProposal): Promise<void> {
    // The relationship must be yours; the table has no policies, only the server writes it.
    const owned = await this.loadRelationship(userId, p.relationshipId);
    if (owned === null) throw new NotFoundError('relationship');
    check(
      await this.db.from('relationship_proposals').upsert(
        {
          message_id: p.messageId,
          alt_index: p.altIndex,
          relationship_id: p.relationshipId,
          kind: p.kind,
          evidence: p.evidence,
          reason: p.reason,
        },
        { onConflict: 'message_id,alt_index' },
      ),
      'proposal',
    );
  }

  async loadProposal(userId: string, messageId: string, altIndex: number): Promise<StoredProposal | null> {
    const row = check(
      await this.db.from('relationship_proposals').select('*').eq('message_id', messageId).eq('alt_index', altIndex).maybeSingle(),
      'proposal',
    );
    if (!row) return null;
    const owned = await this.loadRelationship(userId, row.relationship_id);
    if (owned === null) return null;
    return {
      messageId: row.message_id,
      altIndex: row.alt_index,
      relationshipId: row.relationship_id,
      kind: row.kind,
      evidence: row.evidence,
      reason: row.reason,
    };
  }
}
