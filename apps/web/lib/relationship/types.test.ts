import { describe, expect, it } from "vitest";
import { relationshipFromJson } from "./types";

describe("relationshipFromJson", () => {
  it("parses a snapshot into the typed model", () => {
    const rel = relationshipFromJson({
      id: "r1",
      characterId: "c1",
      personaId: "p1",
      type: "friendship",
      pacing: "auto",
      values: { trust: 30, affection: 25, attraction: 0, tension: 2 },
      stages: ["Strangers", "Acquaintances", "Allies"],
      stageIdx: 1,
      version: 3,
      facts: [{ id: "f1", text: "Lost a ship", locked: true, tags: ["past"] }],
      events: [
        { id: "e1", kindId: "promise_made", title: "A promise", why: "You said you'd return", at: "2026-01-01T00:00:00Z" },
      ],
      pending: [],
    });

    expect(rel).not.toBeNull();
    expect(rel?.stages[rel.stageIdx]).toBe("Acquaintances");
    expect(rel?.values.trust).toBe(30);
    expect(rel?.facts[0].tags).toEqual(["past"]);
    expect(rel?.events[0].title).toBe("A promise");
    expect(rel?.version).toBe(3);
  });

  it("returns null for junk", () => {
    expect(relationshipFromJson(null)).toBeNull();
    expect(relationshipFromJson({})).toBeNull();
  });
});
