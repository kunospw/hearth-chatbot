import type { ReplyFn } from "./reply";

// A local, canned reply source for the signed-out preview — no backend, no
// model. Streams a themed reply word-group by word-group so the chat UI,
// throttle and roleplay styling are demoable. Mirrors FakeReplyStreamingService.

const REPLIES: Record<string, string[]> = {
  morrow: [
    '*squints at you over the lantern* "Storm\'s coming in off the point." He taps ash from his pipe. "You\'d be wiser indoors — but I won\'t stop you standing a while."',
    '*coils a length of wet rope, not looking up* "Most folk want something from a harbour like this." A long breath. "What is it you\'re after?"',
  ],
  vesper: [
    'The lamp turns, and for a moment the whole room is bright. *Vesper sets down the logbook* "I don\'t usually have visitors this far up the stair."',
    '*traces a line on the chart* "Three ships this month, all steering wide of the shoal." A pause. "You notice things. I like that."',
  ],
  jun: [
    '*ladles broth into a chipped bowl and slides it to you* "On the house — you look like you\'ve walked a long way." The griddle hisses behind him.',
    '"Everyone\'s got a story they trade for supper." *grins, wiping his hands* "Tonight it\'s your turn. Start anywhere."',
  ],
  _default: [
    '*looks up as you approach* "Didn\'t expect company." A small, cautious smile. "But I\'m glad of it."',
  ],
};

export function createPreviewReply(characterId: string): ReplyFn {
  let counter = 0;
  return (request, handlers, signal) =>
    new Promise<string>((resolve, reject) => {
      const list = REPLIES[characterId] ?? REPLIES._default;
      const full = list[counter++ % list.length];
      const groups = full.split(/(?<=\s)(?=\S)/); // keep whitespace with words
      const wordsPerTick = 3;
      let i = 0;
      let shown = "";
      let timer: ReturnType<typeof setTimeout> | null = null;
      let aborted = false;

      const cleanup = () => {
        if (timer) clearTimeout(timer);
        signal?.removeEventListener("abort", onAbort);
      };
      function onAbort() {
        aborted = true;
        cleanup();
        const e = new Error("aborted");
        e.name = "AbortError";
        reject(e);
      }

      if (signal?.aborted) {
        onAbort();
        return;
      }
      signal?.addEventListener("abort", onAbort);
      handlers.onServerInfo?.({ freeRepliesLeft: null, modelId: request.modelId });

      const step = () => {
        if (aborted) return;
        const end = Math.min(i + wordsPerTick, groups.length);
        for (; i < end; i++) shown += groups[i];
        if (request.stream) handlers.onText?.(shown);
        if (i < groups.length) {
          timer = setTimeout(step, 60);
        } else {
          if (!request.stream) handlers.onText?.(full);
          handlers.onServerInfo?.({ done: true });
          cleanup();
          resolve(full);
        }
      };
      // Brief "thinking" pause, then stream.
      timer = setTimeout(step, 700);
    });
}
