// Reads a server-sent-event byte stream from fetch(). Events are separated by a
// blank line; only `event:` and `data:` lines matter. Bad JSON is skipped.
// Port of parseSse in lib/core/backend/backend_api.dart.

export interface SseEvent {
  event: string;
  data: Record<string, unknown>;
}

export async function* parseSse(
  body: ReadableStream<Uint8Array>,
): AsyncGenerator<SseEvent> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true }).replace(/\r\n/g, "\n");
      let end: number;
      while ((end = buffer.indexOf("\n\n")) >= 0) {
        const block = buffer.slice(0, end);
        buffer = buffer.slice(end + 2);
        const e = readBlock(block);
        if (e) yield e;
      }
    }
    const tail = readBlock(buffer.trim());
    if (tail) yield tail;
  } finally {
    reader.releaseLock();
  }
}

function readBlock(block: string): SseEvent | null {
  if (!block.trim()) return null;
  let event = "message";
  let data = "";
  for (const line of block.split("\n")) {
    if (line.startsWith("event:")) {
      event = line.slice(6).trim();
    } else if (line.startsWith("data:")) {
      data += line.slice(5).trim();
    }
  }
  try {
    const parsed: unknown = data ? JSON.parse(data) : {};
    return {
      event,
      data:
        parsed && typeof parsed === "object"
          ? (parsed as Record<string, unknown>)
          : { value: parsed },
    };
  } catch {
    return null;
  }
}
