import { describe, expect, it } from "vitest";
import type { CharacterRow } from "./database.types";
import { characterFromRow, characterToRow } from "./mappers";
import type { Character } from "@/lib/domain/types";

const CHARACTER: Character = {
  id: "c1",
  name: "Captain Morrow",
  first: "Morrow",
  initial: "M",
  tile: 0xff3b1f27,
  ink: 0xffe9a0ae,
  short: "A weathered captain.",
  universeId: null,
  portraitAsset: null,
  portraitUrl: null,
  tags: ["Adventure", "Gruff"],
  intro: "Intro.",
  personality: "Gruff but kind.",
  speaking: "Clipped.",
  greeting: '*nods* "Evening."',
  exampleDialogue: "",
  rules: "",
  relationships: "",
  scenario: "",
  archived: false,
};

describe("character mappers", () => {
  it("round-trips a character through a row", () => {
    const row = characterToRow(CHARACTER, "user-1") as unknown as CharacterRow;
    expect(characterFromRow(row)).toEqual(CHARACTER);
  });

  it("writes the owner id onto the row", () => {
    const row = characterToRow(CHARACTER, "user-1");
    expect(row.user_id).toBe("user-1");
    expect(row.example_dialogue).toBe("");
  });
});
