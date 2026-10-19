-- Relationship journal tables (docs/RELATIONSHIP_ENGINE.md, "Database").
--
-- OWNERSHIP RULE: relationship values are owned by the server. The app can READ
-- these tables (RLS: your rows) but has no insert/update/delete policy on them,
-- so it can never write a number. Changes go through the edge functions
-- (chat_turn, apply_correction), which run the engine and then call
-- commit_relationship() with the service role.

create table public.relationships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  character_id uuid not null references public.characters on delete cascade,
  universe_id uuid references public.universes on delete set null,
  persona_id uuid not null references public.personas on delete cascade,
  type text not null default 'undecided'
    check (type in ('undecided', 'platonic', 'romantic', 'familial', 'rivalrous', 'other')),
  pacing text not null default 'slow' check (pacing in ('slow', 'balanced', 'fast', 'manual')),
  trust numeric(5,1) not null default 20 check (trust between 0 and 100),
  affection numeric(5,1) not null default 15 check (affection between 0 and 100),
  attraction numeric(5,1) not null default 0 check (attraction between 0 and 100),
  tension numeric(5,1) not null default 0 check (tension between 0 and 100),
  stage_idx integer not null default 0,
  stage_locked boolean not null default false,
  romantic_from integer,
  -- optimistic locking: every commit bumps it, a stale writer is rejected
  version integer not null default 0,
  -- user turns seen so far, and how many small moments were not counted
  turn integer not null default 0,
  ignored integer not null default 0,
  -- normalised text of recent user messages as "turn|text" (repeat filter)
  recent_hashes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- one relationship per user x character x universe x persona
  unique nulls not distinct (user_id, character_id, universe_id, persona_id)
);

create table public.relationship_stages (
  relationship_id uuid not null references public.relationships on delete cascade,
  idx integer not null,
  name text not null,
  primary key (relationship_id, idx)
);

-- Append-only: an undo adds a reversing event and sets undone_by on the
-- original. Rows are never deleted (except with the relationship itself).
create table public.relationship_events (
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.relationships on delete cascade,
  -- plain uuids on purpose: events outlive a deleted chat ("from a deleted chat")
  conversation_id uuid,
  message_id uuid,
  kind text,                                   -- catalogue kind, 'undo', 'correction' or null (milestones)
  category text not null check (category in ('milestone', 'setback', 'reconcile', 'shift', 'correction')),
  title text not null,
  source text not null check (source in ('engine', 'model_proposal', 'user', 'undo', 'approved', 'setup')),
  deltas jsonb not null default '{}'::jsonb,
  multipliers jsonb not null default '{}'::jsonb,
  evidence text,
  why text not null default '',
  chat_title text not null default 'Story',
  turn integer not null default 0,
  stage_before integer,
  stage_after integer,
  undoable boolean not null default false,
  undone_by uuid references public.relationship_events,
  undo_of uuid references public.relationship_events,
  from_deleted_chat boolean not null default false,
  -- insertion order (newest first in the journal); created_at can tie inside one commit
  seq bigint generated always as identity,
  created_at timestamptz not null default now()
);
create index relationship_events_rel_idx on public.relationship_events (relationship_id, seq desc);
create index relationship_events_conv_idx on public.relationship_events (conversation_id);
-- Idempotence: a message counts once per kind. An undone event no longer
-- blocks (an edited message is evaluated again).
create unique index relationship_events_once on public.relationship_events (message_id, kind)
  where message_id is not null and kind is not null and undone_by is null;

create table public.relationship_facts (
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.relationships on delete cascade,
  text text not null,
  locked boolean not null default true,
  tags text[] not null default '{}',
  seq bigint generated always as identity,
  created_at timestamptz not null default now()
);

create table public.relationship_suggestions (
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.relationships on delete cascade,
  kind text not null,
  category text not null,
  title text not null,
  deltas jsonb not null default '{}'::jsonb,
  multipliers jsonb not null default '{}'::jsonb,
  why text not null default '',
  evidence text,
  source text not null default 'engine',
  chat_title text not null default 'Story',
  conversation_id uuid,
  message_id uuid,
  turn integer not null default 0,
  status text not null default 'pending',
  seq bigint generated always as identity,
  created_at timestamptz not null default now()
);
create index relationship_suggestions_rel_idx on public.relationship_suggestions (relationship_id)
  where status = 'pending';

-- What the model proposed for each version of each reply. Written only by
-- chat_turn, so a switched-back version can be counted again without trusting
-- anything the app says about what the model "proposed".
create table public.relationship_proposals (
  message_id uuid not null,
  alt_index integer not null default 0,
  relationship_id uuid not null references public.relationships on delete cascade,
  kind text not null,
  evidence text not null,
  reason text not null default '',
  created_at timestamptz not null default now(),
  primary key (message_id, alt_index)
);
alter table public.relationship_proposals enable row level security;
revoke all on public.relationship_proposals from authenticated, anon;

-- ── RLS: read your own, write nothing ─────────────────────────────────────
alter table public.relationships enable row level security;
alter table public.relationship_stages enable row level security;
alter table public.relationship_events enable row level security;
alter table public.relationship_facts enable row level security;
alter table public.relationship_suggestions enable row level security;

create policy relationships_read on public.relationships for select to authenticated
  using (user_id = auth.uid());
create policy relationship_stages_read on public.relationship_stages for select to authenticated
  using (exists (select 1 from public.relationships r where r.id = relationship_id and r.user_id = auth.uid()));
create policy relationship_events_read on public.relationship_events for select to authenticated
  using (exists (select 1 from public.relationships r where r.id = relationship_id and r.user_id = auth.uid()));
create policy relationship_facts_read on public.relationship_facts for select to authenticated
  using (exists (select 1 from public.relationships r where r.id = relationship_id and r.user_id = auth.uid()));
create policy relationship_suggestions_read on public.relationship_suggestions for select to authenticated
  using (exists (select 1 from public.relationships r where r.id = relationship_id and r.user_id = auth.uid()));

-- Belt and braces: no write privilege at all for the app's roles.
revoke insert, update, delete, truncate on
  public.relationships, public.relationship_stages, public.relationship_events,
  public.relationship_facts, public.relationship_suggestions
from authenticated, anon;

-- ── a deleted chat keeps its events, marked ───────────────────────────────
create function public.mark_events_from_deleted_chat() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.relationship_events set from_deleted_chat = true where conversation_id = old.id;
  update public.relationship_suggestions set conversation_id = null where conversation_id = old.id;
  return old;
end $$;

create trigger conversations_mark_events before delete on public.conversations
  for each row execute function public.mark_events_from_deleted_chat();
