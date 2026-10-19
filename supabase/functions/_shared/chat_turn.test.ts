import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RelationshipEngine } from './engine/engine.ts';
import { handleChatTurn, type ChatTurnDeps } from './chat_turn.ts';
import { LlmError, type LlmClient, type LlmRequest } from './ollama.ts';
import { parseSse } from './sse.ts';
import { FakeStore, ids, sampleContext } from '../../tests/support/fake_store.ts';

class FakeLlm implements LlmClient {
  calls: LlmRequest[] = [];
  chunks: string[];
  failWith?: Error;
  hang: boolean;
  constructor(chunks: string[], failWith?: Error, hang = false) {
    this.chunks = chunks;
    this.failWith = failWith;
    this.hang = hang;
  }
  async *stream(req: LlmRequest, signal?: AbortSignal): AsyncIterable<string> {
    this.calls.push(req);
    if (signal?.aborted) return;
    if (this.failWith && this.chunks.length === 0) throw this.failWith;
    for (const c of this.chunks) {
      if (signal?.aborted) return;
      yield c;
    }
    if (this.hang && !signal?.aborted) await new Promise((res) => signal?.addEventListener('abort', () => res(null)));
    if (this.failWith) throw this.failWith;
  }
}

let n = 0;
function setup(llm: LlmClient, over = {}) {
  const store = new FakeStore(sampleContext(over));
  const deps: ChatTurnDeps = {
    store,
    llm,
    engine: new RelationshipEngine(() => `00000000-0000-4000-8000-${String(++n).padStart(12, '0')}`),
    now: () => new Date('2026-03-10T09:00:00Z'),
  };
  return { store, deps };
}

const body = (extra: Record<string, unknown> = {}) => ({
  conversationId: ids.conversation,
  personaId: ids.persona,
  modelId: 'ember',
  userMessageId: ids.user1,
  aiMessageId: ids.aiNew,
  ...extra,
});

async function run(deps: ChatTurnDeps, b: unknown, userId?: string) {
  const res = await handleChatTurn(b, userId ?? (deps.store as FakeStore).userId, deps);
  const raw = await res.text();
  const isSse = (res.headers.get('content-type') ?? '').includes('event-stream');
  return { res, raw, events: isSse ? parseSse(raw) : [], json: isSse ? null : JSON.parse(raw) };
}

const tag = (j: unknown) => `<relationship_event>${JSON.stringify(j)}</relationship_event>`;

test('a turn streams the reply, judges your message first, and never shows the tag', async () => {
  const llm = new FakeLlm(['*Vesper studies you.* "Your ', 'word," she says. ', tag({ kind: 'vulnerability_shared', evidence: 'Your word', reason: 'Vesper opened up' })]);
  const { store, deps } = setup(llm);
  const { res, events } = await run(deps, body());
  assert.equal(res.status, 200);
  assert.deepEqual(events.map((e) => e.event), ['start', 'delta', 'delta', 'done']);

  // the engine saw the user's promise before the model wrote anything
  const start = events[0].data;
  assert.equal(start.userNote.text, 'Trust grew');
  assert.equal(start.relationship.values.trust, 24);
  assert.deepEqual(start.usage, { modelId: 'ember', used: 1, limit: 30 });

  const shown = events.filter((e) => e.event === 'delta').map((e) => e.data.text).join('');
  assert.equal(shown, '*Vesper studies you.* "Your word," she says. ');
  const done = events[3].data;
  assert.equal(done.text, '*Vesper studies you.* "Your word," she says.');
  assert.doesNotMatch(JSON.stringify(events), /relationship_event/);

  // the model's proposal was validated (the quote is in the reply) and counted
  assert.equal(done.note.text, 'Trust grew');
  assert.equal(done.note.reason, 'Vesper opened up');
  assert.equal(done.relationship.events.filter((e: any) => e.kindId === 'vulnerability_shared').length, 1);
  assert.equal(done.relationship.events[0].source, 'modelProposal');
  assert.equal(store.proposals.size, 1);
  assert.equal(store.consumed, 1);
});

test('the prompt carries the relationship block and the history, built on the server', async () => {
  const llm = new FakeLlm(['ok.']);
  const { deps } = setup(llm);
  await run(deps, body());
  const req = llm.calls[0];
  assert.equal(req.model, 'test-model'); // the real model name comes from the database, not the app
  assert.equal(req.messages[0].role, 'system');
  assert.match(req.messages[0].content, /\[relationship — set by the app, read-only\]/);
  // the promise was judged first, so the block already reflects it
  assert.match(req.messages[0].content, /trust 24/);
  assert.match(req.messages[0].content, /latest turning point: You made a promise/);
  assert.deepEqual(req.messages.slice(1).map((m) => m.role), ['assistant', 'user']);
});

test('invented evidence is rejected: no event, no note', async () => {
  const llm = new FakeLlm(['She smiles. ', tag({ kind: 'rescue', evidence: 'I pulled you from the sea', reason: 'x' })]);
  const { deps } = setup(llm);
  const { events } = await run(deps, body({ userMessageId: undefined }));
  const done = events.find((e) => e.event === 'done')!.data;
  assert.equal(done.note, null);
  assert.equal(done.relationship.events.length, 0);
  assert.equal(done.relationship.ignored, 1);
});

test('an unknown kind or a second event is discarded', async () => {
  const llm = new FakeLlm(['Hi there friend. ', tag({ kind: 'teleport', evidence: 'Hi', reason: 'x' })]);
  const { deps } = setup(llm);
  const { events } = await run(deps, body({ userMessageId: undefined }));
  assert.equal(events.find((e) => e.event === 'done')!.data.note, null);
});

test('retrying the same message does not count it twice', async () => {
  const { store, deps } = setup(new FakeLlm(['ok.']));
  await run(deps, body());
  const first = store.relationships.values().next().value!;
  const again = await run(deps, body());
  assert.equal(again.events[0].data.userNote, null);
  assert.equal(store.relationships.values().next().value!.values.trust, first.values.trust);
  assert.equal(store.relationships.values().next().value!.events.length, first.events.length);
});

test('no free replies left: 429 before anything streams, and your message was still judged', async () => {
  const { store, deps } = setup(new FakeLlm(['x']));
  store.replies.get('ember')!.left = 0;
  const { res, json } = await run(deps, body());
  assert.equal(res.status, 429);
  assert.equal(json.error.code, 'model_limit');
  assert.equal(json.userNote.text, 'Trust grew');
});

test('a busy or unknown model gets its own answer', async () => {
  const { store, deps } = setup(new FakeLlm(['x']));
  store.replies.set('atlas', { left: null, busy: true, ollamaModel: 'big' });
  assert.equal((await run(deps, body({ modelId: 'atlas' }))).json.error.code, 'model_busy');
  assert.equal((await run(deps, body({ modelId: 'nope', userMessageId: undefined }))).json.error.code, 'unknown_model');
});

test('when the model fails before writing anything, the free reply is given back', async () => {
  const { store, deps } = setup(new FakeLlm([], new LlmError('busy', 503, 'x')));
  const { events } = await run(deps, body({ userMessageId: undefined }));
  const err = events.find((e) => e.event === 'error')!.data;
  assert.equal(err.code, 'model_busy');
  assert.equal(store.refunds, 1);
  assert.equal(store.replies.get('ember')!.left, 30);
  assert.equal(events.some((e) => e.event === 'done'), false);
});

test('an empty reply is an error, and refunded', async () => {
  const { store, deps } = setup(new FakeLlm(['   ']));
  const { events } = await run(deps, body({ userMessageId: undefined }));
  assert.equal(events.find((e) => e.event === 'error')!.data.code, 'empty_reply');
  assert.equal(store.refunds, 1);
});

test('stopping before any text refunds; stopping with text keeps the reply counted', async () => {
  for (const [chunks, refunds] of [[[], 1], [['Some words. '], 0]] as const) {
    const { store, deps } = setup(new FakeLlm([...chunks], undefined, true));
    const abort = new AbortController();
    const res = await handleChatTurn(body({ userMessageId: undefined }), store.userId, deps, abort.signal);
    const reader = res.body!.getReader();
    await reader.read(); // start
    if (chunks.length) await reader.read(); // delta
    abort.abort();
    for (;;) if ((await reader.read()).done) break;
    assert.equal(store.refunds, refunds, JSON.stringify(chunks));
  }
});

test('a rewrite leaves the replaced reply out of the prompt and asks for something different', async () => {
  const ctx = sampleContext();
  ctx.messages.push({ id: ids.ai2, role: 'ai', alts: ['She laughed softly and looked away.'], altIndex: 0 });
  const llm = new FakeLlm(['A different answer.']);
  const { deps } = setup(llm, { messages: ctx.messages });
  await run(deps, body({ userMessageId: undefined, replaceMessageId: ids.ai2, aiMessageId: ids.ai2, altIndex: 1 }));
  const req = llm.calls[0];
  assert.doesNotMatch(JSON.stringify(req.messages.slice(1)), /laughed softly/);
  assert.match(req.messages[0].content, /laughed softly/); // …but it is named as the thing to avoid
  assert.match(req.messages[0].content, /different version/);
});

test('settings are clamped and mapped; mature content follows the account', async () => {
  const llm = new FakeLlm(['ok.']);
  const { deps } = setup(llm, { adultContent: true });
  await run(deps, body({ userMessageId: undefined, settings: { length: 'long', style: 'literary', temperature: 99, maxTokens: 5, repetitionPenalty: 1.2, contextDepth: 1000 } }));
  const req = llm.calls[0];
  assert.equal(req.temperature, 2);
  assert.equal(req.maxTokens, 64);
  assert.match(req.messages[0].content, /turned on mature content/);
  assert.match(req.messages[0].content, /under 18/);
});

test('someone else’s conversation, an unsaved message and bad input are refused', async () => {
  const { deps } = setup(new FakeLlm(['x']));
  assert.equal((await run(deps, body(), '99999999-9999-4999-8999-999999999999')).res.status, 404);
  assert.equal((await run(deps, body({ userMessageId: ids.user2 }))).res.status, 409);
  assert.equal((await run(deps, { ...body(), conversationId: 'nope' })).res.status, 400);
  assert.equal((await run(deps, null)).res.status, 400);
  assert.equal((await run(deps, body({ settings: { length: 'enormous' } }))).res.status, 400);
  // the AI message cannot be passed off as a user message
  assert.equal((await run(deps, body({ userMessageId: ids.ai1 }))).res.status, 409);
});

test('a version conflict while committing is retried', async () => {
  const { store, deps } = setup(new FakeLlm(['ok.']));
  store.conflicts = 2;
  const { events } = await run(deps, body());
  assert.equal(events[0].data.userNote.text, 'Trust grew');
});
