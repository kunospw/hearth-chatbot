import { test } from 'node:test';
import assert from 'node:assert/strict';
import { LlmError, OllamaClient, classifyStatus, parseNdjson } from './ollama.ts';

const stream = (parts: string[]): ReadableStream<Uint8Array> =>
  new ReadableStream({
    start(c) {
      for (const p of parts) c.enqueue(new TextEncoder().encode(p));
      c.close();
    },
  });

async function collect(it: AsyncIterable<string>): Promise<string[]> {
  const out: string[] = [];
  for await (const t of it) out.push(t);
  return out;
}

const line = (content: string, extra: object = {}) => JSON.stringify({ message: { role: 'assistant', content }, done: false, ...extra }) + '\n';

test('NDJSON: reply text only, even when lines are split across chunks', async () => {
  const whole = line('Hel') + line('lo ') + line('there') + JSON.stringify({ done: true, message: { content: '' } }) + '\n';
  for (const size of [1, 7, 1000]) {
    const parts: string[] = [];
    for (let i = 0; i < whole.length; i += size) parts.push(whole.slice(i, i + size));
    assert.equal((await collect(parseNdjson(stream(parts)))).join(''), 'Hello there', `chunk ${size}`);
  }
});

test('NDJSON: reasoning ("thinking") is never shown; multi-byte text survives a split', async () => {
  const withThinking = JSON.stringify({ message: { thinking: 'hmm', content: '' }, done: false }) + '\n' + line('héllo — ✓');
  const bytes = new TextEncoder().encode(withThinking);
  const mid = bytes.indexOf(0xc3) + 1; // split inside "é"
  const s = new ReadableStream<Uint8Array>({
    start(c) {
      c.enqueue(bytes.slice(0, mid));
      c.enqueue(bytes.slice(mid));
      c.close();
    },
  });
  assert.equal((await collect(parseNdjson(s))).join(''), 'héllo — ✓');
});

test('NDJSON: an error line becomes an LlmError; a last line without a newline still counts', async () => {
  await assert.rejects(collect(parseNdjson(stream([JSON.stringify({ error: 'model not found' }) + '\n']))), LlmError);
  assert.deepEqual(await collect(parseNdjson(stream([line('a') + line('b').trim()]))), ['a', 'b']);
});

test('statuses map to what the app can explain', () => {
  assert.equal(classifyStatus(401), 'auth');
  assert.equal(classifyStatus(404), 'unavailable');
  assert.equal(classifyStatus(429), 'rate_limit');
  assert.equal(classifyStatus(503), 'busy');
  assert.equal(classifyStatus(500), 'other');
});

test('the client sends the key as a bearer token and never leaks it into the body', async () => {
  let seen: { url: string; init: RequestInit } | undefined;
  const client = new OllamaClient({
    apiKey: 'sekret',
    fetch: (async (url: string, init: RequestInit) => {
      seen = { url, init };
      return new Response(line('ok'), { status: 200 });
    }) as unknown as typeof fetch,
  });
  const out = await collect(client.stream({ model: 'm', messages: [{ role: 'user', content: 'hi' }], temperature: 0.5, maxTokens: 100, repetitionPenalty: 1.1 }));
  assert.deepEqual(out, ['ok']);
  assert.equal(seen!.url, 'https://ollama.com/api/chat');
  assert.equal((seen!.init.headers as Record<string, string>).authorization, 'Bearer sekret');
  assert.doesNotMatch(String(seen!.init.body), /sekret/);
  const b = JSON.parse(String(seen!.init.body));
  assert.equal(b.stream, true);
  assert.deepEqual(b.options, { temperature: 0.5, num_predict: 1400, repeat_penalty: 1.1 });
});

test('an HTTP error before the stream is an LlmError with the right kind', async () => {
  const client = new OllamaClient({ apiKey: 'k', fetch: (async () => new Response('x', { status: 503 })) as unknown as typeof fetch });
  await assert.rejects(
    collect(client.stream({ model: 'm', messages: [], temperature: 1, maxTokens: 10, repetitionPenalty: 1 })),
    (e: unknown) => e instanceof LlmError && e.kind === 'busy' && e.status === 503,
  );
});
