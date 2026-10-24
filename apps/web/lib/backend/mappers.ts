import type {
  CharacterRow,
  ConversationRow,
  MemoryRow,
  MessageRow,
  ModelRow,
  PersonaRow,
  ProfileRow,
  UniverseRow,
} from "./database.types";
import type {
  AiModel,
  Character,
  Conversation,
  Memory,
  MemoryCategory,
  Message,
  Persona,
  Profile,
  RelationshipNote,
  Universe,
} from "@/lib/domain/types";

// Rows (snake_case) <-> the app's models. Port of lib/core/backend/mappers.dart.

const s = (v: unknown): string => (typeof v === "string" ? v : "");
const n = (v: unknown): number => (typeof v === "number" ? v : Number(v) || 0);

// ── characters ────────────────────────────────────────────────────────────

export function characterToRow(
  c: Character,
  userId: string,
  portraitUrl?: string | null,
): Record<string, unknown> {
  return {
    id: c.id,
    user_id: userId,
    name: c.name,
    first: c.first,
    initial: c.initial,
    short: c.short,
    tile_color: c.tile,
    ink_color: c.ink,
    universe_id: c.universeId,
    portrait_asset: c.portraitAsset,
    portrait_url: portraitUrl ?? c.portraitUrl,
    tags: c.tags,
    intro: c.intro,
    personality: c.personality,
    speaking: c.speaking,
    greeting: c.greeting,
    example_dialogue: c.exampleDialogue,
    rules: c.rules,
    relationships: c.relationships,
    scenario: c.scenario,
    archived: c.archived,
  };
}

export function characterFromRow(r: CharacterRow): Character {
  return {
    id: r.id,
    name: s(r.name),
    first: s(r.first),
    initial: s(r.initial),
    tile: n(r.tile_color),
    ink: n(r.ink_color),
    short: s(r.short),
    universeId: r.universe_id ?? null,
    portraitAsset: r.portrait_asset ?? null,
    portraitUrl: r.portrait_url ?? null,
    tags: Array.isArray(r.tags) ? r.tags.map(String) : [],
    intro: s(r.intro),
    personality: s(r.personality),
    speaking: s(r.speaking),
    greeting: s(r.greeting),
    exampleDialogue: s(r.example_dialogue),
    rules: s(r.rules),
    relationships: s(r.relationships),
    scenario: s(r.scenario),
    archived: r.archived === true,
  };
}

// ── library ───────────────────────────────────────────────────────────────

export function universeToRow(u: Universe, userId: string): Record<string, unknown> {
  return {
    id: u.id,
    user_id: userId,
    name: u.name,
    era: u.era,
    tile_color: u.tile,
    description: u.description,
  };
}

export function universeFromRow(r: UniverseRow): Universe {
  return {
    id: r.id,
    name: s(r.name),
    era: s(r.era),
    tile: n(r.tile_color),
    description: s(r.description),
  };
}

const MEMORY_CATEGORIES: MemoryCategory[] = [
  "important",
  "facts",
  "relationships",
  "world",
];

export function memoryToRow(m: Memory, userId: string): Record<string, unknown> {
  return {
    id: m.id,
    user_id: userId,
    universe_id: m.universeId,
    category: m.category,
    text: m.text,
    pinned: m.pinned,
  };
}

export function memoryFromRow(r: MemoryRow): Memory {
  const cat = MEMORY_CATEGORIES.includes(r.category as MemoryCategory)
    ? (r.category as MemoryCategory)
    : "facts";
  return {
    id: r.id,
    universeId: r.universe_id,
    category: cat,
    text: s(r.text),
    pinned: r.pinned === true,
  };
}

export function personaToRow(p: Persona, userId: string): Record<string, unknown> {
  return {
    id: p.id,
    user_id: userId,
    name: p.name,
    initial: p.initial,
    description: p.description,
  };
}

export function personaFromRow(r: PersonaRow): Persona {
  return {
    id: r.id,
    name: s(r.name),
    initial: s(r.initial),
    description: s(r.description),
  };
}

// ── models ────────────────────────────────────────────────────────────────

export function modelFromRow(r: ModelRow): AiModel {
  return {
    id: r.id,
    name: s(r.name),
    description: s(r.description),
    dailyFreeReplies: r.daily_free_replies == null ? null : n(r.daily_free_replies),
    busy: r.busy === true,
  };
}

// ── profile ───────────────────────────────────────────────────────────────

export function profileFromRow(r: ProfileRow): Profile {
  return {
    id: r.id,
    displayName: s(r.display_name),
    adultContent: r.adult_content === true,
  };
}

// ── relationship notes (stored on messages) ────────────────────────────────

export function noteToJson(note: RelationshipNote): Record<string, unknown> {
  return {
    text: note.text,
    story: note.story,
    entryId: note.entryId,
    kindId: note.kindId,
    evidence: note.evidence,
    reason: note.reason,
  };
}

export function noteFromJson(j: Record<string, unknown>): RelationshipNote {
  return {
    text: s(j.text),
    story: s(j.story),
    entryId: (j.entryId as string) ?? null,
    kindId: (j.kindId as string) ?? null,
    evidence: (j.evidence as string) ?? null,
    reason: (j.reason as string) ?? null,
  };
}

// ── conversations & messages ──────────────────────────────────────────────

export function conversationToRow(
  c: Conversation,
  userId: string,
): Record<string, unknown> {
  return {
    id: c.id,
    user_id: userId,
    character_id: c.characterId,
    title: c.title,
    mode: c.mode,
    pinned: c.pinned,
    archived: c.archived,
    persona_id: c.personaId,
    updated_at: new Date(c.updatedAt).toISOString(),
  };
}

export function conversationFromRow(
  r: ConversationRow,
  messages: Message[],
): Conversation {
  return {
    id: r.id,
    characterId: r.character_id,
    title: s(r.title),
    updatedAt: r.updated_at ?? new Date().toISOString(),
    messages,
    pinned: r.pinned === true,
    mode: r.mode === "story" ? "story" : "chat",
    archived: r.archived === true,
    personaId: r.persona_id ?? null,
  };
}

export function messageToRow(
  m: Message,
  conversationId: string,
  userId: string,
): Record<string, unknown> {
  const notes: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(m.notes)) notes[k] = noteToJson(v);
  return {
    id: m.id,
    conversation_id: conversationId,
    user_id: userId,
    role: m.role === "user" ? "user" : "ai",
    alts: m.alts,
    alt_index: m.altIndex,
    notes,
  };
}

export function messageFromRow(r: MessageRow): Message {
  const alts = Array.isArray(r.alts) ? r.alts.map(String) : [];
  const notes: Record<number, RelationshipNote> = {};
  if (r.notes && typeof r.notes === "object") {
    for (const [k, v] of Object.entries(r.notes)) {
      const i = Number.parseInt(k, 10);
      if (!Number.isNaN(i) && v && typeof v === "object") {
        notes[i] = noteFromJson(v as Record<string, unknown>);
      }
    }
  }
  return {
    id: r.id,
    role: r.role === "user" ? "user" : "ai",
    alts: alts.length ? alts : [""],
    altIndex: n(r.alt_index ?? 0),
    notes,
  };
}
