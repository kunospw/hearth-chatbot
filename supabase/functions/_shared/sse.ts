// Server-sent events for the chat stream.
//   event: start | delta | done | error      data: <json>

export const SSE_HEADERS = {
  'content-type': 'text/event-stream; charset=utf-8',
  'cache-control': 'no-cache, no-transform',
  connection: 'keep-alive',
  'x-accel-buffering': 'no',
};

export function sseEvent(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

/** Reads events back (used by tests, and the Dart client has its own port of this). */
export function parseSse(text: string): { event: string; data: any }[] {
  const out: { event: string; data: any }[] = [];
  for (const block of text.split('\n\n')) {
    if (block.trim() === '') continue;
    let event = 'message';
    let data = '';
    for (const line of block.split('\n')) {
      if (line.startsWith('event:')) event = line.slice(6).trim();
      else if (line.startsWith('data:')) data += line.slice(5).trim();
    }
    out.push({ event, data: data === '' ? null : JSON.parse(data) });
  }
  return out;
}
