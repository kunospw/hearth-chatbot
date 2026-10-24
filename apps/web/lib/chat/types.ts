import type { Relationship } from "@/lib/relationship/types";
import type { RelationshipNote } from "@/lib/domain/types";

// The chat-turn request/response shapes and generation state. Mirrors
// ReplyRequest / ReplySettings / ServerTurnInfo / ReplyException in
// lib/features/chat/data/reply_streaming_service.dart.

/** AI settings as the server needs them (Settings -> AI). */
export interface ReplySettings {
  length: string; // short | medium | long
  style: string; // descriptive | ...
  temperature: number;
  maxTokens: number;
  repetitionPenalty: number;
  contextDepth: number;
}

export const DEFAULT_REPLY_SETTINGS: ReplySettings = {
  length: "medium",
  style: "descriptive",
  temperature: 0.9,
  maxTokens: 600,
  repetitionPenalty: 1.1,
  contextDepth: 40,
};

/** Everything chat_turn needs. The server loads the conversation and builds
 * the prompt itself, so this sends ids and preferences only. */
export interface ReplyRequest {
  conversationId: string;
  personaId: string;
  modelId: string;
  /** The id of the reply being written, and which version of it this is. */
  aiMessageId: string;
  altIndex: number;
  settings: ReplySettings;
  /** The message just sent (already saved), if this reply answers one. */
  userMessageId?: string | null;
  /** A Rewrite: the reply being replaced. */
  replaceMessageId?: string | null;
  /** False when animations are off: emit the whole reply at once. */
  stream: boolean;
}

/** What the server reports about a turn, before and after the reply. */
export interface ServerTurnInfo {
  userNote?: RelationshipNote | null;
  replyNote?: RelationshipNote | null;
  relationship?: Relationship | null;
  /** Free replies left today on modelId (null = no daily limit). */
  freeRepliesLeft?: number | null;
  modelId?: string;
  /** True for the report at the end of the reply. */
  done?: boolean;
}

/** The server could not produce the reply. */
export class ReplyError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = "ReplyError";
    this.code = code;
  }
  get isModelProblem(): boolean {
    return (
      this.code === "model_limit" ||
      this.code === "model_busy" ||
      this.code === "model_unavailable" ||
      this.code === "unknown_model"
    );
  }
}

export type GenStatus = "idle" | "thinking" | "streaming";
