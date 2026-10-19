-- Hearth core schema: profiles, library, characters, conversations, models.
-- Relationships live in the next migration. RLS is on for every table and every
-- policy is "this row belongs to auth.uid()".

-- ── profiles ──────────────────────────────────────────────────────────────
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null default '',
  -- Off by default. When on, the server's prompt allows mature themes between
  -- adult characters. The hard rule (nothing sexual involving minors) is
  -- always in the prompt and cannot be switched off. See functions/_shared/prompt.ts.
  adult_content boolean not null default false,
  created_at timestamptz not null default now()
);

-- ── library ───────────────────────────────────────────────────────────────
create table public.universes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  era text not null default 'Your own world',
  tile_color bigint not null,
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index universes_user_idx on public.universes (user_id);

create table public.personas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  initial text not null default '?',
  description text not null default '',
  -- "Just me": the no-persona option every account starts with.
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index personas_user_idx on public.personas (user_id);
create unique index personas_one_default on public.personas (user_id) where is_default;

create table public.characters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  first text not null,
  initial text not null,
  short text not null default '',
  tile_color bigint not null,
  ink_color bigint not null,
  universe_id uuid references public.universes on delete set null,
  portrait_asset text,
  portrait_url text,
  tags text[] not null default '{}',
  intro text not null default '',
  personality text not null default '',
  speaking text not null default '',
  greeting text not null default '',
  example_dialogue text not null default '',
  rules text not null default '',
  relationships text not null default '',
  scenario text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index characters_user_idx on public.characters (user_id, created_at desc);

create table public.memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  universe_id uuid not null references public.universes on delete cascade,
  category text not null check (category in ('important', 'facts', 'relationships', 'world')),
  text text not null,
  pinned boolean not null default false,
  pos bigint generated always as identity,
  created_at timestamptz not null default now()
);
create index memories_universe_idx on public.memories (universe_id, pos);

-- ── conversations ─────────────────────────────────────────────────────────
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  character_id uuid not null references public.characters on delete cascade,
  title text not null default 'New chat',
  mode text not null default 'chat' check (mode in ('chat', 'story')),
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index conversations_user_idx on public.conversations (user_id, updated_at desc);
create index conversations_character_idx on public.conversations (character_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role text not null check (role in ('ai', 'user')),
  -- Every version of the reply (Rewrite adds one). User messages have one.
  alts jsonb not null check (jsonb_typeof(alts) = 'array' and jsonb_array_length(alts) >= 1),
  alt_index integer not null default 0 check (alt_index >= 0),
  -- "Trust grew a little": one note per version, keyed by alt index. Words only.
  notes jsonb not null default '{}'::jsonb,
  seq bigint generated always as identity,
  created_at timestamptz not null default now()
);
create index messages_conversation_idx on public.messages (conversation_id, seq);

-- ── models and daily free replies ─────────────────────────────────────────
-- The app shows friendly names; `ollama_model` is the real Ollama Cloud model
-- and never leaves the server.
create table public.models (
  id text primary key,
  name text not null,
  description text not null default '',
  ollama_model text not null,
  daily_free_replies integer,          -- null = no daily limit
  busy boolean not null default false, -- shown as "busy right now"
  enabled boolean not null default true,
  sort integer not null default 0
);

create table public.model_usage (
  user_id uuid not null references auth.users on delete cascade,
  model_id text not null references public.models on delete cascade,
  day date not null default ((now() at time zone 'utc')::date),
  used integer not null default 0,
  primary key (user_id, model_id, day)
);

-- Placeholder mapping. Ollama renames and retires cloud models, so confirm the
-- real ids against https://ollama.com/api/tags (with your key) and edit
-- `ollama_model` in the dashboard (Table editor → models). See supabase/README.md.
insert into public.models (id, name, description, ollama_model, daily_free_replies, busy, sort) values
  ('ember', 'Ember', 'Quick and dependable for everyday roleplay', 'deepseek-v4-flash', 30, false, 1),
  ('lumen', 'Lumen', 'A little slower, with longer, richer replies', 'kimi-k2.6', 50, false, 2),
  ('atlas', 'Atlas Pro', 'Best for long stories and big worlds', 'gpt-oss:120b', null, true, 3);

-- ── updated_at ────────────────────────────────────────────────────────────
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger universes_touch before update on public.universes
  for each row execute function public.touch_updated_at();
create trigger characters_touch before update on public.characters
  for each row execute function public.touch_updated_at();

-- ── new accounts get a profile and the "Just me" persona ──────────────────
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  insert into public.personas (user_id, name, initial, description, is_default)
  values (new.id, 'Just me', 'M', 'No persona. You speak as yourself.', true);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── row level security ────────────────────────────────────────────────────
alter table public.profiles enable row level security;
alter table public.universes enable row level security;
alter table public.personas enable row level security;
alter table public.characters enable row level security;
alter table public.memories enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.models enable row level security;
alter table public.model_usage enable row level security;

create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- One policy per table: your rows, all operations. `with check` stops you
-- writing a row that points at someone else's parent (below).
create policy universes_own on public.universes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy personas_own on public.personas for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy characters_own on public.characters for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (universe_id is null or exists (
      select 1 from public.universes u where u.id = universe_id and u.user_id = auth.uid()))
  );

create policy memories_own on public.memories for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.universes u where u.id = universe_id and u.user_id = auth.uid())
  );

create policy conversations_own on public.conversations for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.characters c where c.id = character_id and c.user_id = auth.uid())
  );

create policy messages_own on public.messages for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.conversations c where c.id = conversation_id and c.user_id = auth.uid())
  );

-- Everyone signed in can read the model list; nobody can change it from the app.
create policy models_read on public.models for select to authenticated using (enabled);
-- Usage is readable by its owner. Only the server writes it.
create policy model_usage_read on public.model_usage for select to authenticated
  using (user_id = auth.uid());

-- The server-only column: `models.ollama_model` must not reach the app. Grant
-- column access instead of the whole table.
revoke all on public.models from authenticated, anon;
grant select (id, name, description, daily_free_replies, busy, sort) on public.models to authenticated;
revoke all on public.model_usage from authenticated, anon;
grant select on public.model_usage to authenticated;

-- ── portraits ─────────────────────────────────────────────────────────────
-- A public bucket with unguessable file names; only you can write under your
-- own folder (`<user id>/<file>`).
insert into storage.buckets (id, name, public)
values ('portraits', 'portraits', true)
on conflict (id) do nothing;

create policy portraits_write on storage.objects for insert to authenticated
  with check (bucket_id = 'portraits' and (storage.foldername(name))[1] = auth.uid()::text);
create policy portraits_update on storage.objects for update to authenticated
  using (bucket_id = 'portraits' and (storage.foldername(name))[1] = auth.uid()::text);
create policy portraits_delete on storage.objects for delete to authenticated
  using (bucket_id = 'portraits' and (storage.foldername(name))[1] = auth.uid()::text);
