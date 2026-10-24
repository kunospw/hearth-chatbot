import { hexToArgb } from "@/lib/backend/color";
import type { Character } from "@/lib/domain/types";

// A tiny read-only sample set so the UI renders before a Supabase project is
// connected (signed-out preview). Replaced by real data once signed in.

function sample(p: Partial<Character> & Pick<Character, "id" | "name" | "first">): Character {
  return {
    initial: p.first.slice(0, 1).toUpperCase(),
    tile: hexToArgb("#3B1F27"),
    ink: hexToArgb("#E9A0AE"),
    short: "",
    universeId: null,
    portraitAsset: null,
    portraitUrl: null,
    tags: [],
    intro: "",
    personality: "",
    speaking: "",
    greeting: "",
    exampleDialogue: "",
    rules: "",
    relationships: "",
    scenario: "",
    archived: false,
    ...p,
  };
}

export const sampleCharacters: Character[] = [
  sample({
    id: "morrow",
    name: "Captain Morrow",
    first: "Morrow",
    tile: hexToArgb("#3B1F27"),
    ink: hexToArgb("#E9A0AE"),
    short: "A weathered harbour captain with a soft spot for strays.",
    tags: ["Adventure", "Gruff"],
    greeting:
      '*leans on the weather-worn railing, watching you approach* "Didn\'t reckon on company at this hour." The harbour lights sway on the black water. "Name\'s Morrow. State your business — or just your name."',
  }),
  sample({
    id: "vesper",
    name: "Vesper",
    first: "Vesper",
    tile: hexToArgb("#1F2E3B"),
    ink: hexToArgb("#BFD9D6"),
    short: "A lighthouse keeper who keeps more than lamps alight.",
    tags: ["Slow burn", "Mystery"],
    greeting:
      'The lamp sweeps the dark and settles. *Vesper looks up from the logbook* "You climbed all those stairs." A faint smile. "Few people bother. What brings you to the light?"',
  }),
  sample({
    id: "jun",
    name: "Jun",
    first: "Jun",
    tile: hexToArgb("#2E2A1F"),
    ink: hexToArgb("#F2CF9A"),
    short: "A night-market cook trading stories for coin.",
    tags: ["Warm", "Slice of life"],
    greeting:
      '*the griddle hisses as he waves you to a stool* "Sit, sit — you look half-starved." He slides a bowl across the counter. "First one\'s free. Stories cost extra."',
  }),
];
