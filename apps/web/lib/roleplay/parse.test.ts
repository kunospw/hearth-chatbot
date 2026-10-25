import { describe, expect, it } from "vitest";
import { parseRoleplay, stripRoleplay } from "./parse";

describe("parseRoleplay", () => {
  it("parses an action then an unclosed quote running to the end", () => {
    expect(parseRoleplay('*waves* "Hello')).toEqual([
      [
        { kind: "action", text: "waves" },
        { kind: "narration", text: " " },
        { kind: "dialogue", text: "“Hello" },
      ],
    ]);
  });

  it("lets an action sit inside dialogue, resuming dialogue after", () => {
    expect(parseRoleplay('"I\'m *fine*"')).toEqual([
      [
        { kind: "dialogue", text: "“I'm " },
        { kind: "action", text: "fine" },
        { kind: "dialogue", text: "”" },
      ],
    ]);
  });

  it("renders closed dialogue with typographic quotes", () => {
    expect(parseRoleplay('She paused. "Later."')).toEqual([
      [
        { kind: "narration", text: "She paused. " },
        { kind: "dialogue", text: "“Later.”" },
      ],
    ]);
  });

  it("splits paragraphs on newlines and drops blank ones", () => {
    expect(parseRoleplay("one\n\ntwo")).toEqual([
      [{ kind: "narration", text: "one" }],
      [{ kind: "narration", text: "two" }],
    ]);
  });

  it("does not emit an empty action run from stray **", () => {
    expect(parseRoleplay("a**b")).toEqual([[{ kind: "narration", text: "ab" }]]);
  });
});

describe("stripRoleplay", () => {
  it("removes markup and collapses whitespace", () => {
    expect(stripRoleplay('*waves*   "Hi"\nthere')).toBe('waves "Hi" there');
  });
});
