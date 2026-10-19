// chat_turn: one turn of a conversation, on the server.
//
//   1. check the request, load your conversation, character, persona, memories
//   2. engine pre-step: judge your new message (the app never does)
//   3. count the reply against the model's daily free replies
//   4. build the prompt (with the relationship block) and stream the reply
//   5. validate the ONE relationship event the model may propose, then persist
//
// The reply is a stream of server-sent events:
//   start  {userNote, relationship, usage}  once, before any text
//   delta  {text}                         as the reply is written
//   done   {text, note, altIndex, relationship}
//   error  {code, message}                after start, if the model fails
// Failures before the stream starts are ordinary JSON: {error:{code,message}}
// with a status the app understands (429 limit, 503 busy, 400 …).
import { RelationshipEngine } from './engine/engine.ts';
import { relationshipToJson, type Relationship, type RelationshipNote } from './engine/models.ts';
import { LlmError, type LlmClient } from './ollama.ts';
import {
  DEFAULT_SETTINGS,
  StreamFilter,
  buildMessages,
  buildSystemPrompt,
  parseModelReply,
  type ChatSettings,
  type ContextMessage,
} from './prompt.ts';
import { SSE_HEADERS, sseEvent } from './sse.ts';
import { NotFoundError, type ChatContext, type Store } from './store.ts';
import { mutate } from './mutate.ts';
import { BadRequestError, clampNumber, int, obj, oneOf, optUuid, text, uuid } from './validate.ts';

export interface ChatTurnDeps {
  store: Store;
  llm: LlmClient;
  engine: RelationshipEngine;
  now: () => Date;
}

export interface ChatTurnRequest {
  conversationId: string;
  personaId: string;
  modelId: string;
  /** The message you just sent (already saved). Omit for Continue / Rewrite. */
  userMessageId?: string;
  /** A Rewrite: the reply being replaced (it is not part of the prompt). */
  replaceMessageId?: string;
  /** The id of the reply being written. */
  aiMessageId: string;
  altIndex: number;
  settings: ChatSettings;
}

export function parseChatTurn(body: unknown): ChatTurnRequest {
  const b = obj(body);
  const s = b.settings === undefined || b.settings === null ? {} : obj(b.settings, 'settings');
  const d = DEFAULT_SETTINGS;
  return {
    conversationId: uuid(b.conversationId, 'conversationId'),
    personaId: uuid(b.personaId, 'personaId'),
    modelId: text(b.modelId, 'modelId', 40, { min: 1 }),
    userMessageId: optUuid(b.userMessageId, 'userMessageId'),
    replaceMessageId: optUuid(b.replaceMessageId, 'replaceMessageId'),
    aiMessageId: uuid(b.aiMessageId, 'aiMessageId'),
    altIndex: b.altIndex === undefined ? 0 : int(b.altIndex, 'altIndex', 0, 50),
    settings: {
      length: s.length === undefined ? d.length : oneOf(s.length, ['short', 'medium', 'long'] as const, 'settings.length'),
      style: s.style === undefined ? d.style : oneOf(s.style, ['casual', 'descriptive', 'literary'] as const, 'settings.style'),
      temperature: clampNumber(s.temperature, 0, 2, d.temperature),
      maxTokens: Math.round(clampNumber(s.maxTokens, 64, 2000, d.maxTokens)),
      repetitionPenalty: clampNumber(s.repetitionPenalty, 1, 2, d.repetitionPenalty),
      contextDepth: Math.round(clampNumber(s.contextDepth, 4, 80, d.contextDepth)),
    },
  };
}

export const jsonResponse = (status: number, body: unknown): Response =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

export const errorResponse = (status: number, code: string, message: string, extra: Record<string, unknown> = {}): Response =>
  jsonResponse(status, { error: { code, message }, ...extra });

const textOf = (m: { alts: string[]; altIndex: number }): string => m.alts[Math.min(Math.max(m.altIndex, 0), m.alts.length - 1)] ?? '';

export async function handleChatTurn(
  body: unknown,
  userId: string,
  deps: ChatTurnDeps,
  signal?: AbortSignal,
): Promise<Response> {
  let req: ChatTurnRequest;
  try {
    req = parseChatTurn(body);
  } catch (e) {
    if (e instanceof BadRequestError) return errorResponse(400, e.code, e.message);
    throw e;
  }
  const { store, engine, llm } = deps;

  const ctx = await store.loadContext(userId, req.conversationId, req.personaId);
  if (ctx === null) return errorResponse(404, 'not_found', 'That conversation was not found.');

  let relationship: Relationship;
  try {
    relationship = await store.ensureRelationship(userId, ctx.character.id, ctx.persona.id);
  } catch (e) {
    if (e instanceof NotFoundError) return errorResponse(404, 'not_found', 'That character was not found.');
    throw e;
  }

  // ── 2. the engine looks at your message ────────────────────────────────────
  let userNote: RelationshipNote | null = null;
  if (req.userMessageId !== undefined) {
    const msg = ctx.messages.find((m) => m.id === req.userMessageId);
    if (msg === undefined || msg.role !== 'user') {
      return errorResponse(409, 'message_not_found', 'Your message has not been saved yet. Try again.');
    }
    const turnText = textOf(msg);
    const out = await mutate(store, userId, relationship.id, (r) => {
      const o = engine.processUserMessage(r, {
        messageId: msg.id,
        text: turnText,
        now: deps.now(),
        conversationId: ctx.conversation.id,
        chatTitle: ctx.conversation.title,
      });
      return { next: o.relationship, result: o.kind === 'ignored' ? null : o.note };
    });
    relationship = out.relationship;
    userNote = out.result;
  }

  // ── 3. one of today's free replies ─────────────────────────────────────────
  const consumed = await store.consumeReply(userId, req.modelId);
  if (!consumed.ok) {
    const extra = { userNote, relationship: relationshipToJson(relationship) };
    if (consumed.reason === 'limit') return errorResponse(429, 'model_limit', 'No free replies left on this model today.', extra);
    if (consumed.reason === 'busy') return errorResponse(503, 'model_busy', 'This model is busy right now.', extra);
    return errorResponse(400, 'unknown_model', 'That model is not available.', extra);
  }

  // ── 4. the prompt ──────────────────────────────────────────────────────────
  const replaced = req.replaceMessageId === undefined ? undefined : ctx.messages.find((m) => m.id === req.replaceMessageId);
  const upTo = replaced === undefined ? ctx.messages : ctx.messages.slice(0, ctx.messages.indexOf(replaced));
  const history: ContextMessage[] = upTo
    .filter((m) => m.id !== req.aiMessageId)
    .map((m) => ({ id: m.id, role: m.role, text: textOf(m) }));
  const system = buildSystemPrompt({
    character: ctx.character,
    personaName: ctx.persona.name,
    personaDescription: ctx.persona.description,
    universe: ctx.universe,
    memories: ctx.memories,
    relationship,
    mode: ctx.conversation.mode,
    settings: req.settings,
    adultContent: ctx.adultContent,
    avoidText: replaced === undefined ? null : textOf(replaced),
  });
  const messages = buildMessages(system, history, req.settings.contextDepth);
  const ollamaModel = consumed.ollamaModel;

  const events = new TransformStream<string, string>();
  const writer = events.writable.getWriter();
  const abort = new AbortController();
  signal?.addEventListener('abort', () => abort.abort());
  const send = (event: string, data: unknown) => writer.write(sseEvent(event, data)).catch(() => abort.abort());

  const refund = () => store.refundReply(userId, req.modelId).catch(() => {});

  (async () => {
    let shown = '';
    try {
      await send('start', {
        userNote,
        relationship: relationshipToJson(relationship),
        // today's free replies on this model, so the app can show how many are left
        usage: { modelId: req.modelId, used: consumed.used, limit: consumed.limit },
      });
      if (abort.signal.aborted) {
        // The app stopped before the model began: nothing was written.
        await refund();
        return;
      }
      const filter = new StreamFilter();
      for await (const chunk of llm.stream(
        {
          model: ollamaModel,
          messages,
          temperature: req.settings.temperature,
          maxTokens: req.settings.maxTokens,
          repetitionPenalty: req.settings.repetitionPenalty,
        },
        abort.signal,
      )) {
        const out = filter.push(chunk);
        if (out !== '') {
          shown += out;
          await send('delta', { text: out });
        }
      }
      const rest = filter.flush();
      if (rest !== '') {
        shown += rest;
        await send('delta', { text: rest });
      }
      if (abort.signal.aborted) {
        if (shown.trim() === '') await refund();
        return;
      }
      const parsed = parseModelReply(filter.full);
      if (parsed.text.trim() === '') {
        await refund();
        const m = llm.lastMeta?.();
        const why = m
          ? ` (stopped: ${m.doneReason ?? 'unknown'}; ${m.thinkingChars > 0 ? `it spent ${m.thinkingChars} characters thinking and wrote none` : 'it sent no text at all'}${m.tokens !== undefined ? `; ${m.tokens} tokens used` : ''})`
          : '';
        await send('error', { code: 'empty_reply', message: `The model did not write anything${why}.` });
        return;
      }

      // ── 5. the model's proposal, validated like anything else ───────────────
      let note: RelationshipNote | null = null;
      if (parsed.proposal !== null) {
        const draft = parsed.proposal;
        await store.saveProposal(userId, {
          messageId: req.aiMessageId,
          altIndex: req.altIndex,
          relationshipId: relationship.id,
          kind: draft.kind,
          evidence: draft.evidence,
          reason: draft.reason,
        });
        const recent = [...history.map((m) => m.text), parsed.text];
        const out = await mutate(store, userId, relationship.id, (r) => {
          const o = engine.processModelProposal(
            r,
            {
              kindId: draft.kind,
              evidence: draft.evidence,
              reason: draft.reason,
              messageId: req.aiMessageId,
              recentMessages: recent,
              now: deps.now(),
              conversationId: ctx.conversation.id,
              chatTitle: ctx.conversation.title,
            },
            { characterFirst: ctx.character.first },
          );
          return { next: o.relationship, result: o.kind === 'ignored' ? null : o.note };
        });
        relationship = out.relationship;
        note = out.result;
      }
      await send('done', {
        text: parsed.text,
        note,
        altIndex: req.altIndex,
        relationship: relationshipToJson(relationship),
      });
    } catch (e) {
      if (shown.trim() === '') await refund();
      console.error('chat_turn', e instanceof LlmError ? `${e.kind} ${e.message}` : e);
      if (!abort.signal.aborted) {
        const err = describeError(e);
        await send('error', err);
      }
    } finally {
      await writer.close().catch(() => {});
    }
  })();

  return new Response(events.readable.pipeThrough(new TextEncoderStream()), { status: 200, headers: SSE_HEADERS });
}

export function describeError(e: unknown): { code: string; message: string } {
  if (e instanceof LlmError) {
    switch (e.kind) {
      case 'busy':
      case 'rate_limit':
        return { code: 'model_busy', message: 'This model is busy right now.' };
      case 'unavailable':
        return { code: 'model_unavailable', message: `This model is not available right now (${e.message}).` };
      case 'auth':
        return { code: 'server_error', message: `The server could not use the model key (${e.message}).` };
      default:
        return { code: 'model_error', message: `The model had a problem (${e.message}). Try again.` };
    }
  }
  return { code: 'server_error', message: 'Something went wrong on our side. Try again.' };
}

export type { ChatContext };
