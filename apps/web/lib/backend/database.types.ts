// Row shapes as Postgres stores them (snake_case), for the tables the web
// client reads/writes directly under RLS. Matches supabase/migrations/*.sql.
// The client is intentionally untyped (dynamic maps, like the Flutter app);
// these interfaces type the mapper boundary.

export interface ProfileRow {
  id: string;
  display_name: string | null;
  adult_content: boolean;
  created_at: string;
}

export interface UniverseRow {
  id: string;
  user_id: string;
  name: string;
  era: string | null;
  tile_color: number;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface PersonaRow {
  id: string;
  user_id: string;
  name: string;
  initial: string | null;
  description: string | null;
  is_default: boolean;
  created_at: string;
}

export interface CharacterRow {
  id: string;
  user_id: string;
  name: string;
  first: string | null;
  initial: string | null;
  short: string | null;
  tile_color: number;
  ink_color: number;
  universe_id: string | null;
  portrait_asset: string | null;
  portrait_url: string | null;
  tags: string[] | null;
  intro: string | null;
  personality: string | null;
  speaking: string | null;
  greeting: string | null;
  example_dialogue: string | null;
  rules: string | null;
  relationships: string | null;
  scenario: string | null;
  archived: boolean;
  created_at: string;
  updated_at: string;
}

export interface MemoryRow {
  id: string;
  user_id: string;
  universe_id: string;
  category: string;
  text: string;
  pinned: boolean;
  pos: number | null;
  created_at: string;
}

export interface ConversationRow {
  id: string;
  user_id: string;
  character_id: string;
  title: string;
  mode: string;
  pinned: boolean;
  archived: boolean;
  persona_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface MessageRow {
  id: string;
  conversation_id: string;
  user_id: string;
  role: string;
  alts: string[] | null;
  alt_index: number | null;
  notes: Record<string, unknown> | null;
  seq: number;
  created_at: string;
}

/** Only the columns the app is allowed to read (ollama_model is hidden). */
export interface ModelRow {
  id: string;
  name: string;
  description: string | null;
  daily_free_replies: number | null;
  busy: boolean;
  sort: number;
}

export interface ModelUsageRow {
  user_id: string;
  model_id: string;
  day: string;
  used: number;
}
