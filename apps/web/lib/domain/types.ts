// The app's domain models (camelCase), mirroring the Flutter domain classes.
// Row <-> model conversion lives in lib/backend/mappers.ts.

export type ChatMode = "chat" | "story";
export type MessageRole = "user" | "ai";
export type MemoryCategory = "important" | "facts" | "relationships" | "world";

export interface Character {
  id: string;
  name: string;
  first: string;
  initial: string;
  /** ARGB32 ints (see lib/backend/color.ts). */
  tile: number;
  ink: number;
  short: string;
  universeId: string | null;
  portraitAsset: string | null;
  portraitUrl: string | null;
  tags: string[];
  intro: string;
  personality: string;
  speaking: string;
  greeting: string;
  exampleDialogue: string;
  rules: string;
  relationships: string;
  scenario: string;
  archived: boolean;
}

export interface Universe {
  id: string;
  name: string;
  era: string;
  tile: number;
  description: string;
}

export interface Memory {
  id: string;
  universeId: string;
  category: MemoryCategory;
  text: string;
  pinned: boolean;
}

export interface Persona {
  id: string;
  name: string;
  initial: string;
  description: string;
}

export interface AiModel {
  id: string;
  name: string;
  description: string;
  /** null means no daily limit. */
  dailyFreeReplies: number | null;
  busy: boolean;
}

export interface Profile {
  id: string;
  displayName: string;
  adultContent: boolean;
}

/** A one-line "why this changed" note attached to a message (per alt index). */
export interface RelationshipNote {
  text: string;
  story: string;
  entryId: string | null;
  kindId: string | null;
  evidence: string | null;
  reason: string | null;
}

export interface Message {
  id: string;
  role: MessageRole;
  /** Reply versions; at least one entry. The visible one is alts[altIndex]. */
  alts: string[];
  altIndex: number;
  notes: Record<number, RelationshipNote>;
}

export interface Conversation {
  id: string;
  characterId: string;
  title: string;
  updatedAt: string; // ISO 8601
  messages: Message[];
  pinned: boolean;
  mode: ChatMode;
  archived: boolean;
  personaId: string | null;
}

export function isUserMessage(m: Message): boolean {
  return m.role === "user";
}

/** The currently visible reply text. */
export function visibleText(m: Message): string {
  return m.alts[m.altIndex] ?? m.alts[0] ?? "";
}
