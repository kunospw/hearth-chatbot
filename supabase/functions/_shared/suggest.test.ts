import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleSuggest, buildSuggestPrompt, parseSuggestions } from './suggest.ts';
import { LlmError, type LlmClient, type LlmRequest } from './ollama.ts';
import { FakeStore, ids, sampleContext } from '../../tests/support/fake_store.ts';

class FakeLlm implements LlmClient {
  calls: LlmRequest[] = [];
  chunks: string[];
  fail?: Error;
  constructor(chunks: string[], fail?: Error) {
    this.chunks = chunks;
    this.fail = fail;
  }
  async *stream(req: LlmRequest): AsyncIterable<string> {
    this.calls.push(req);
    if (this.fail) throw this.fail;
    for (const c of this.chunks) yield c;
  }
}

const body = (extra: Record<string, unknown> = {}) => ({
  conversationId: ids.conversation,
  personaId: ids.persona,
  modelId: 'ember',
  ...extra,
});

const call = async (llm: LlmClient, b: unknown, user?: string) => {
  const store = new FakeStore(sampleContext());
  const res = await handleSuggest(b, user ?? store.userId, { store, llm });
  return { res, json: await res.json(), store };
};

test('parseSuggestions: JSON, fenced JSON, bullet lists, duplicates and junk', () => {
  assert.deepEqual(parseSuggestions('["One thing.", "Another *smiles*.", "Third one here"]', 3), [
    'One thing.',
    'Another *smiles*.',
    'Third one here',
  ]);
  assert.deepEqual(parseSuggestions('Sure!\n```json\n["a b c", "d e f"]\n```', 3), ['a b c', 'd e f']);
  assert.deepEqual(parseSuggestions('1. First idea\n2) Second idea\n- Third idea\n', 3), [
    'First idea',
    'Second idea',
    'Third idea',
  ]);
  assert.deepEqual(parseSuggestions('["same", "Same", "other one"]', 3), ['same', 'other one']);
  assert.deepEqual(parseSuggestions('["aa","bb","cc","dd"]', 2), ['aa', 'bb']);
  assert.deepEqual(parseSuggestions('', 3), []);
});

test('the prompt is written as the user, never as the character, and carries the content rules', () => {
  const ctx = sampleContext({ adultContent: true });
  const { system, user } = buildSuggestPrompt(ctx, 3);
  assert.match(system, /The user plays Wren/);
  assert.match(system, /Never write Vesper's words/);
  assert.match(system, /JSON array of 3 strings/);
  assert.match(system, /under 18/);
  assert.match(system, /turned on mature content/);
  assert.match(user, /Wren: I promise I will keep your secret/);
  assert.match(user, /Vesper: The lamp is lit\./);
});

test('returns the suggestions, and uses the real model without spending a free reply', async () => {
  const llm = new FakeLlm(['["I lean closer. *smiles*", "What are you hiding, Vesper?", "Show me the logbook."]']);
  const { res, json, store } = await call(llm, body());
  assert.equal(res.status, 200);
  assert.equal(json.suggestions.length, 3);
  assert.equal(llm.calls[0].model, 'test-model');
  assert.equal(store.consumed, 0);
});

test('count is respected and clamped; bad input is refused', async () => {
  const llm = new FakeLlm(['["aa aa", "bb bb", "cc cc", "dd dd"]']);
  assert.equal((await call(llm, body({ count: 2 }))).json.suggestions.length, 2);
  assert.equal((await call(llm, body({ count: 9 }))).res.status, 400);
  assert.equal((await call(llm, { ...body(), conversationId: 'x' })).res.status, 400);
  assert.equal((await call(llm, null)).res.status, 400);
});

test('someone else’s chat, an unknown model, no ideas, and a model that fails', async () => {
  assert.equal((await call(new FakeLlm(['[]']), body(), '99999999-9999-4999-8999-999999999999')).res.status, 404);
  assert.equal((await call(new FakeLlm(['x']), body({ modelId: 'nope' }))).json.error.code, 'unknown_model');
  const empty = await call(new FakeLlm(['']), body());
  assert.equal(empty.res.status, 502);
  assert.equal(empty.json.error.code, 'no_suggestions');
  const failed = await call(new FakeLlm([], new LlmError('busy', 503, 'x')), body());
  assert.equal(failed.res.status, 502);
});
