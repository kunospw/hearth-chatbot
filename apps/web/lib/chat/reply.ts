import type { BackendApi } from "@/lib/backend/api";
import { BackendError, OfflineError, isAbortError } from "@/lib/backend/errors";
import { noteFromJson } from "@/lib/backend/mappers";
import type { RelationshipNote } from "@/lib/domain/types";
import { type Relationship, relationshipFromJson } from "@/lib/relationship/types";
import { ReplyError, type ReplyRequest, type ServerTurnInfo } from "./types";

// Replies from the server's chat_turn function. The server loads the
// conversation, judges your message, builds the prompt with the relationship
// block and validates the one event the model may propose, so this sends ids
// and preferences only. Port of ServerReplyStreamingService.streamReply.

export interface ReplyHandlers {
  /** Relationship/usage reports: once at start, once at done. */
  onServerInfo?(info: ServerTurnInfo): void;
  /** Cumulative reply text as it streams (replace what you show). */
  onText?(cumulative: string): void;
}

/** A source of replies: the server (streamChatTurn) or a preview mock. */
export type ReplyFn = (
  request: ReplyRequest,
  handlers: ReplyHandlers,
  signal?: AbortSignal,
) => Promise<string>;

function note(v: unknown): RelationshipNote | null {
  return v && typeof v === "object"
    ? noteFromJson(v as Record<string, unknown>)
    : null;
}

function rel(v: unknown): Relationship | null {
  return relationshipFromJson(v);
}

function parseStart(d: Record<string, unknown>, modelId: string): ServerTurnInfo {
  const usage = d.usage;
  let left: number | null | undefined;
  if (usage && typeof usage === "object") {
    const u = usage as { limit?: unknown; used?: unknown };
    if (u.limit != null && u.used != null) left = Number(u.limit) - Number(u.used);
  }
  return {
    userNote: note(d.userNote),
    relationship: rel(d.relationship),
    freeRepliesLeft: left,
    modelId,
  };
}

/**
 * Streams one chat turn. Resolves with the final reply text; rejects with a
 * ReplyError, OfflineError, or an AbortError when stopped (pass signal and
 * call controller.abort() to stop — the server sees the connection close).
 */
export async function streamChatTurn(
  api: BackendApi,
  request: ReplyRequest,
  handlers: ReplyHandlers,
  signal?: AbortSignal,
): Promise<string> {
  const body: Record<string, unknown> = {
    conversationId: request.conversationId,
    personaId: request.personaId,
    modelId: request.modelId,
    aiMessageId: request.aiMessageId,
    altIndex: request.altIndex,
    settings: request.settings,
  };
  if (request.userMessageId) body.userMessageId = request.userMessageId;
  if (request.replaceMessageId) body.replaceMessageId = request.replaceMessageId;

  let text = "";
  let finished = false;

  try {
    for await (const ev of api.stream("chat_turn", body, signal)) {
      try {
        switch (ev.event) {
          case "start":
            handlers.onServerInfo?.(parseStart(ev.data, request.modelId));
            break;
          case "delta": {
            text += typeof ev.data.text === "string" ? ev.data.text : "";
            if (request.stream) handlers.onText?.(text);
            break;
          }
          case "done": {
            const finalText =
              typeof ev.data.text === "string" ? ev.data.text : text;
            if (finalText !== text || !request.stream) handlers.onText?.(finalText);
            text = finalText;
            handlers.onServerInfo?.({
              replyNote: note(ev.data.note),
              relationship: rel(ev.data.relationship),
              done: true,
            });
            finished = true;
            break;
          }
          case "error":
            throw new ReplyError(
              typeof ev.data.code === "string" ? ev.data.code : "server_error",
              typeof ev.data.message === "string"
                ? ev.data.message
                : "Something went wrong.",
            );
        }
      } catch (e) {
        if (e instanceof ReplyError) throw e;
        // A reply we cannot read is an error the person sees, not a hang.
        throw new ReplyError(
          "server_error",
          "The reply came back in a form we couldn’t read. Try again.",
        );
      }
    }
  } catch (e) {
    if (isAbortError(e)) throw e; // Stop
    if (e instanceof ReplyError || e instanceof OfflineError) throw e;
    if (e instanceof BackendError) {
      // Before the reply started the error may still carry what your message did.
      const userNote = note(e.body.userNote);
      const relationship = rel(e.body.relationship);
      if (userNote || relationship) {
        handlers.onServerInfo?.({ userNote, relationship });
      }
      throw new ReplyError(e.code, e.message);
    }
    throw new OfflineError();
  }

  // The connection closed without a final word: a dropped connection.
  if (!finished) throw new OfflineError();
  return text;
}
