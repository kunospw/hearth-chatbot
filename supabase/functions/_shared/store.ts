// What the edge functions need from the database. The real implementation
// (supabase_store.ts) uses supabase-js with the service role; tests use an
// in-memory fake. Every method takes the authenticated user id and must only
// ever touch that user's rows.
import type { Relationship } from './engine/models.ts';
import type { RelationshipPatch } from './engine/persist.ts';
import type { CharacterCard } from './prompt.ts';

export class VersionConflictError extends Error {
  constructor() {
    super('version_conflict');
    this.name = 'VersionConflictError';
  }
}

export class NotFoundError extends Error {
  constructor(what: string) {
    super(`not_found: ${what}`);
    this.name = 'NotFoundError';
  }
}

export interface ThreadMessage {
  id: string;
  role: 'ai' | 'user';
  alts: string[];
  altIndex: number;
}

export interface ChatContext {
  conversation: { id: string; characterId: string; title: string; mode: 'chat' | 'story' };
  character: CharacterCard;
  persona: { id: string; name: string; description: string };
  universe: { id: string; name: string; description: string } | null;
  memories: { category: string; text: string; pinned: boolean }[];
  /** In order, oldest first. */
  messages: ThreadMessage[];
  adultContent: boolean;
}

export type ConsumeResult =
  | { ok: true; ollamaModel: string; used: number; limit: number | null }
  | { ok: false; reason: 'limit' | 'busy' | 'unknown_model'; limit?: number | null };

export interface StoredProposal {
  messageId: string;
  altIndex: number;
  relationshipId: string;
  kind: string;
  evidence: string;
  reason: string;
}

export interface Store {
  /** null when the conversation (or persona) is not yours. */
  loadContext(userId: string, conversationId: string, personaId: string): Promise<ChatContext | null>;

  /** Creates the relationship on first use. Throws NotFoundError if you don't own the character or persona. */
  ensureRelationship(userId: string, characterId: string, personaId: string): Promise<Relationship>;
  loadRelationship(userId: string, relationshipId: string): Promise<Relationship | null>;
  /** Applies a patch atomically. Throws VersionConflictError if `rel.version` is stale. */
  commit(userId: string, rel: Relationship, patch: RelationshipPatch): Promise<Relationship>;

  /** One message of yours, with the conversation it belongs to. */
  loadMessage(userId: string, messageId: string): Promise<(ThreadMessage & { conversationId: string; title: string }) | null>;
  loadThread(userId: string, conversationId: string): Promise<ThreadMessage[]>;
  conversationCharacter(userId: string, conversationId: string): Promise<{ characterId: string; first: string } | null>;

  /** The real model behind a friendly id, without using up a free reply. null if unknown or disabled. */
  lookupModel(modelId: string): Promise<{ ollamaModel: string; busy: boolean } | null>;

  consumeReply(userId: string, modelId: string): Promise<ConsumeResult>;
  refundReply(userId: string, modelId: string): Promise<void>;

  saveProposal(userId: string, p: StoredProposal): Promise<void>;
  loadProposal(userId: string, messageId: string, altIndex: number): Promise<StoredProposal | null>;
}
