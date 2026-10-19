// suggest_replies: three short ideas for what YOU could say next.
//
// You ask for them (a button in the chat); the server reads your conversation,
// asks the model to write the options as you, and returns them. Nothing is sent
// or saved: you pick one, edit it and send it yourself. Suggestions do not use
// up a free reply (they are small), but they are not free of charge to Ollama
// either, so the app only asks when you tap the button.
import { errorResponse, jsonResponse } from './chat_turn.ts';
import type { LlmClient } from './ollama.ts';
import { contentPolicy } from './prompt.ts';
import { NotFoundError, type ChatContext, type Store } from './store.ts';
import { BadRequestError, int, obj, text, uuid } from './validate.ts';

export interface SuggestDeps {
  store: Store;
  llm: LlmClient;
}

export function buildSuggestPrompt(ctx: ChatContext, count: number): { system: string; user: string } {
  const c = ctx.character;
  const p = ctx.persona;
  const recent = ctx.messages
    .slice(-10)
    .map((m) => {
      const t = m.alts[Math.min(m.altIndex, m.alts.length - 1)] ?? '';
      return `${m.role === 'user' ? p.name : c.first}: ${t}`;
    })
    .filter((l) => !l.endsWith(': '))
    .join('\n\n');

  const system = [
    `You write the next message for a user in a roleplay. The user plays ${p.name}${p.description ? ` (${p.description})` : ''}. The other character is ${c.name}${c.short ? `: ${c.short}` : ''}.`,
    c.personality ? `${c.first}'s personality: ${c.personality}` : '',
    contentPolicy(ctx.adultContent),
    `Rules:
- Write ${count} DIFFERENT options for what ${p.name} could say or do next, always in first person as ${p.name}.
- Each is 6 to 30 words, natural, in the tone and pace of the scene so far. Put actions in *asterisks* and speech as plain text.
- Make them different in direction: for example one playful or flirtatious, one curious or probing, one bold that moves the story forward.
- Never write ${c.first}'s words, actions or feelings.
- Output ONLY a JSON array of ${count} strings. No explanation, no markdown.`,
  ]
    .filter((s) => s !== '')
    .join('\n\n');

  const user = recent === '' ? `${c.first} is waiting for ${p.name} to speak first.` : `The roleplay so far:\n\n${recent}\n\nWrite ${p.name}'s next message options now.`;
  return { system, user };
}

/** Reads the model's answer: a JSON array, or (if it ignored that) one idea per line. */
export function parseSuggestions(raw: string, max: number): string[] {
  const clean = (s: string): string =>
    s
      .replace(/^\s*(?:[-*•]|\d+[.)])\s+/, '')
      .replace(/^["“”']+|["“”']+$/g, '')
      .trim();
  let items: string[] = [];
  const m = raw.match(/\[[\s\S]*\]/);
  if (m) {
    try {
      const j = JSON.parse(m[0]);
      if (Array.isArray(j)) items = j.filter((x): x is string => typeof x === 'string');
    } catch {
      // fall through to lines
    }
  }
  if (items.length === 0) {
    items = raw
      .replace(/```[a-z]*/g, '')
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l !== '' && l !== '[' && l !== ']');
  }
  const seen = new Set<string>();
  const out: string[] = [];
  for (const i of items) {
    const t = clean(i).replace(/,$/, '').trim();
    const key = t.toLowerCase();
    if (t.length < 2 || t.length > 280 || seen.has(key)) continue;
    seen.add(key);
    out.push(t);
    if (out.length >= max) break;
  }
  return out;
}

export async function handleSuggest(body: unknown, userId: string, deps: SuggestDeps): Promise<Response> {
  try {
    const b = obj(body);
    const conversationId = uuid(b.conversationId, 'conversationId');
    const personaId = uuid(b.personaId, 'personaId');
    const modelId = text(b.modelId, 'modelId', 40, { min: 1 });
    const count = b.count === undefined ? 3 : int(b.count, 'count', 2, 4);

    const model = await deps.store.lookupModel(modelId);
    if (model === null) return errorResponse(400, 'unknown_model', 'That model is not available.');
    if (model.busy) return errorResponse(503, 'model_busy', 'This model is busy right now.');

    const ctx = await deps.store.loadContext(userId, conversationId, personaId);
    if (ctx === null) return errorResponse(404, 'not_found', 'That conversation was not found.');

    const { system, user } = buildSuggestPrompt(ctx, count);
    let raw = '';
    for await (const chunk of deps.llm.stream({
      model: model.ollamaModel,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
      temperature: 1,
      maxTokens: 500,
      repetitionPenalty: 1.1,
    })) {
      raw += chunk;
      if (raw.length > 6000) break;
    }
    const suggestions = parseSuggestions(raw, count);
    if (suggestions.length === 0) return errorResponse(502, 'no_suggestions', 'The model had no ideas this time. Try again.');
    return jsonResponse(200, { suggestions });
  } catch (e) {
    if (e instanceof BadRequestError) return errorResponse(400, e.code, e.message);
    if (e instanceof NotFoundError) return errorResponse(404, 'not_found', 'Not found.');
    console.error('suggest_replies', e);
    return errorResponse(502, 'model_error', 'The model had a problem. Try again.');
  }
}
