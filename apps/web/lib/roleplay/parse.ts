// Parsing for roleplay prose: *actions*, "dialogue" and plain narration.
// Tolerant of half-streamed text: an unclosed * or " simply runs to the end of
// the paragraph, so a reply looks right at every moment while it streams in.
// Port of lib/core/util/roleplay_parser.dart.

export type RoleKind = "narration" | "action" | "dialogue";

export interface RoleSegment {
  kind: RoleKind;
  text: string;
}

const OPEN_QUOTE = "“"; // “
const CLOSE_QUOTE = "”"; // ”

/**
 * Splits text into paragraphs (on newlines) of styled segments.
 * - `*…*` is an action; it can sit inside dialogue, which resumes after it.
 * - `"…"` (or typographic “…”) is dialogue, shown with typographic quotes.
 * - A `"` inside an action stays part of the action.
 */
export function parseRoleplay(text: string): RoleSegment[][] {
  const paragraphs: RoleSegment[][] = [];
  for (const raw of text.split(/\n+/)) {
    if (!raw.trim()) continue;
    const segs: RoleSegment[] = [];
    let mode: RoleKind = "narration";
    // What to return to when an action ends (narration or dialogue).
    let base: RoleKind = "narration";
    let buf = "";

    const flush = (): void => {
      if (!buf) return;
      const s = buf;
      buf = "";
      // Drop whitespace-only action/dialogue runs from `**` or stray markup.
      if (mode !== "narration" && !s.trim()) return;
      const last = segs.length - 1;
      // Merge with the previous run when markup (e.g. `**`) split one run in two.
      if (segs.length && segs[last].kind === mode && mode !== "dialogue") {
        segs[last] = { kind: mode, text: segs[last].text + s };
      } else {
        segs.push({ kind: mode, text: s });
      }
    };

    for (const ch of raw) {
      if (ch === "*") {
        flush();
        if (mode === "action") {
          mode = base;
        } else {
          base = mode;
          mode = "action";
        }
        continue;
      }
      if (
        mode !== "action" &&
        (ch === '"' || ch === OPEN_QUOTE || ch === CLOSE_QUOTE)
      ) {
        if (mode === "dialogue") {
          buf += CLOSE_QUOTE;
          flush();
          mode = "narration";
          base = "narration";
        } else {
          flush();
          mode = "dialogue";
          base = "dialogue";
          buf += OPEN_QUOTE;
        }
        continue;
      }
      buf += ch;
    }
    flush();
    if (segs.length) paragraphs.push(segs);
  }
  return paragraphs;
}

/** Plain one-line preview: markup removed, whitespace collapsed. */
export function stripRoleplay(text: string): string {
  return text.replace(/\*/g, "").replace(/\s+/g, " ").trim();
}
