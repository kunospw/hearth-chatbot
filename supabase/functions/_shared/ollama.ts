// Ollama Cloud, called only from here (never from the device).
//   POST https://ollama.com/api/chat   Authorization: Bearer <OLLAMA_API_KEY>
// Streams newline-delimited JSON: {"message":{"content":"…"},"done":false} … {"done":true}
import type { ChatMessage } from './prompt.ts';

export type LlmErrorKind = 'busy' | 'unavailable' | 'auth' | 'rate_limit' | 'other';

export class LlmError extends Error {
  readonly kind: LlmErrorKind;
  readonly status: number;
  constructor(kind: LlmErrorKind, status: number, message: string) {
    super(message);
    this.name = 'LlmError';
    this.kind = kind;
    this.status = status;
  }
}

export interface LlmRequest {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  maxTokens: number;
  repetitionPenalty: number;
}

/** What the model said about its own reply (not shown as text): why it stopped, and how much it "thought". */
export interface LlmMeta {
  doneReason?: string;
  thinkingChars: number;
  contentChars: number;
  tokens?: number;
}

/** Anything that can stream a reply. The real one calls Ollama; tests pass a fake. */
export interface LlmClient {
  stream(req: LlmRequest, signal?: AbortSignal): AsyncIterable<string>;
  /** About the stream that just ended (optional). */
  lastMeta?(): LlmMeta | undefined;
}

export interface OllamaConfig {
  apiKey: string;
  baseUrl?: string;
  fetch?: typeof fetch;
}

export function classifyStatus(status: number): LlmErrorKind {
  if (status === 401 || status === 403) return 'auth';
  if (status === 404) return 'unavailable';
  if (status === 429) return 'rate_limit';
  if (status === 408 || status === 502 || status === 503 || status === 504 || status === 529) return 'busy';
  return 'other';
}

export class OllamaClient implements LlmClient {
  private readonly cfg: OllamaConfig;
  private meta: LlmMeta | undefined;
  constructor(cfg: OllamaConfig) {
    this.cfg = cfg;
  }

  lastMeta(): LlmMeta | undefined {
    return this.meta;
  }

  async *stream(req: LlmRequest, signal?: AbortSignal): AsyncIterable<string> {
    const f = this.cfg.fetch ?? fetch;
    const res = await f(`${this.cfg.baseUrl ?? 'https://ollama.com'}/api/chat`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${this.cfg.apiKey}` },
      body: JSON.stringify({
        model: req.model,
        messages: req.messages,
        stream: true,
        options: {
          temperature: req.temperature,
          // Reasoning models think before they write; that thinking counts against
          // the cap, so leave room or the reply gets cut off mid-sentence.
          num_predict: req.maxTokens * 2 + 1200,
          repeat_penalty: req.repetitionPenalty,
        },
      }),
      signal,
    });
    if (!res.ok || !res.body) {
      // Keep what Ollama said (short), so a wrong model name or a key problem is visible.
      let said = '';
      try {
        said = (await res.text()).replace(/\s+/g, ' ').slice(0, 200);
      } catch {
        // no body
      }
      throw new LlmError(classifyStatus(res.status), res.status, `ollama ${res.status}${said ? `: ${said}` : ''}`);
    }
    const meta: LlmMeta = { thinkingChars: 0, contentChars: 0 };
    this.meta = meta;
    yield* parseNdjson(res.body, meta);
  }
}

/** Reads Ollama's NDJSON stream and yields only the visible reply text. */
export async function* parseNdjson(body: ReadableStream<Uint8Array>, meta?: LlmMeta): AsyncIterable<string> {
  const reader = body.getReader();
  const dec = new TextDecoder();
  let buf = '';
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      let nl: number;
      while ((nl = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, nl).trim();
        buf = buf.slice(nl + 1);
        const t = readLine(line, meta);
        if (t) yield t;
      }
    }
    const t = readLine(buf.trim(), meta);
    if (t) yield t;
  } finally {
    reader.releaseLock();
  }
}

function readLine(line: string, meta?: LlmMeta): string {
  if (line === '') return '';
  try {
    const j = JSON.parse(line);
    if (j.error) throw new LlmError('other', 500, String(j.error));
    if (meta) {
      if (typeof j.done_reason === 'string') meta.doneReason = j.done_reason;
      if (typeof j.eval_count === 'number') meta.tokens = j.eval_count;
      const th = j.message?.thinking;
      if (typeof th === 'string') meta.thinkingChars += th.length;
    }
    // `message.thinking` (reasoning models) is never shown.
    const c = j.message?.content;
    if (meta && typeof c === 'string') meta.contentChars += c.length;
    return typeof c === 'string' ? c : '';
  } catch (e) {
    if (e instanceof LlmError) throw e;
    return '';
  }
}
