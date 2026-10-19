# Relationship Journal and engine

**Principle:** values are owned by the backend. The model may propose one event, with evidence. A deterministic engine decides whether it counts and by how much, then tells the next reply. Every change is logged, explainable and reversible.

## UI
- **Entry points:** chat ⋯ → Relationship journal; the Story header menu; character details; or the in-chat note "Trust grew a little · Why?", which opens the journal with that timeline entry expanded.
- **During roleplay** (user setting: Subtle notes / Hidden):
  - Chat mode: one muted line under the user message that caused the change.
  - Story mode: a centred italic Newsreader line, "— Something shifted between you. —".
  - Numbers are never shown in either mode.
- **Journal sections:**
  - StageHeader: stage, type, pacing, and a plain-language "Next:" hint.
  - Suggestions waiting for approval (Manual pacing only).
  - "How this shapes X right now": the four behaviour lines, plus an expandable "what the AI is told".
  - Value meters (word + number): Trust, Affection, Attraction, Tension, with an Adjust button.
  - Pacing (Slow burn by default, Balanced, Fast, Manual).
  - Relationship type: Let the story decide / Platonic / Romantic / Family / Rivalry / Something else.
  - Editable stages, with presets: Romance arc, Friendship, Rivalry, Family.
  - Established facts, which can be locked.
  - Timeline: Milestone, Setback, Reconciliation, Small shift, Your correction. Each entry expands to show why it changed, who decided, and Undo.
  - During-roleplay setting.

## Engine loop (per user message, in the `chat_turn` edge function)
1. **Classify** the user's action: rule matchers plus a small classifier pick at most one kind from the catalogue.
2. **Validate**, in this order:
   - **Trivial filter:** fewer than 4 words, an OOC line `(( … ))`, emoji-only, or a normalised-text hash seen in the last 20 turns.
   - **Evidence:** a model proposal must quote text from the last 6 messages, and its kind must be in the catalogue.
   - **Cooldown:** each kind counts at most once per 6 user turns (10 turns for `appreciation`).
   - **Diminishing returns:** × 1/(1+0.5·n), where n = times that kind counted in the last 30 turns.
   - **Scene budget:** at most 8 total points per 10 turns, and ±12 per value per day.
   - **Romance gate:** attraction only applies when the type is Romantic or Undecided. Affection never converts into attraction.
   - **Locks:** a locked stage never moves automatically. Events that contradict a locked fact (by tag) are rejected.
   - **Idempotence:** events are unique on (message_id, kind). Regenerations never double-count; an edited message is re-evaluated and its old event replaced.
   - **Pacing:** multiply last and round to 0.5. Slow burn is ×0.5 for gains and ×0.75 for setbacks; Balanced 1/1; Fast 1.6/1.2. Manual creates a suggestion instead of a change.
3. **Persist** in one transaction: the event row, the new values and the stage. Use the `version` column for optimistic locking.
4. **Build the prompt block** from the fresh state, then stream the reply.
5. **Model proposal** for the character's own actions goes back through step 2. It is never applied directly.

## Stage maths
```
score = 0.6·trust + 0.4·affection − 0.3·tension
stage = highest i with score ≥ thresholds[i]     thresholds = [−∞, 15, 32, 46, 60, 75]
if romanticFrom != null and stage ≥ romanticFrom and not (romance allowed and attraction ≥ 35):
    stage = romanticFrom − 1
hysteresis: a stage only drops once score < threshold[current] − 5
stageLocked → stage is never changed automatically
```
Stage names belong to each relationship, so a custom arc like "Visitor → Keeper of the Stacks" works the same way.

## Event catalogue (server table)
| kind | deltas | notes |
|---|---|---|
| promise_made | trust +4 | |
| promise_kept | trust +6 | needs an earlier promise_made |
| promise_broken | trust −8, tension +6 | |
| help_offered / rescue | trust +3 / +6, affection +1 / +3 | |
| boundary_respected | trust +3, tension −1 | |
| boundary_crossed | trust −3, tension +5 | |
| vulnerability_shared | trust +3, affection +2 | usually character-side |
| conflict | tension +4 | |
| apology / reconciliation | tension −4, trust +2 | only when tension > 10 |
| betrayal | trust −12, affection −4, tension +10 | may drop a stage |
| appreciation | affection +1 | cooldown 10 |
| romantic_gesture | attraction +2 | gated by type |

## Database (Supabase / Postgres)
```sql
create table relationships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users,
  character_id uuid not null, universe_id uuid, persona_id uuid,
  type text not null default 'undecided',
  pacing text not null default 'slow',
  trust numeric(5,1) default 20, affection numeric(5,1) default 15,
  attraction numeric(5,1) default 0, tension numeric(5,1) default 0,
  stage_idx int not null default 0, stage_locked bool not null default false,
  romantic_from int, version int not null default 0,
  unique (user_id, character_id, universe_id, persona_id)
);
create table relationship_stages (relationship_id uuid references relationships on delete cascade, idx int, name text, primary key (relationship_id, idx));
create table relationship_events (               -- append-only
  id uuid primary key default gen_random_uuid(),
  relationship_id uuid references relationships on delete cascade,
  conversation_id uuid, message_id uuid,
  kind text, source text,                         -- engine | model_proposal | user | undo
  deltas jsonb, multipliers jsonb, evidence text, why text,
  stage_before int, stage_after int, undone_by uuid,
  created_at timestamptz default now(),
  unique (message_id, kind)
);
create table relationship_facts (id uuid primary key default gen_random_uuid(), relationship_id uuid references relationships on delete cascade, text text, locked bool default true, tags text[]);
create table relationship_suggestions (id uuid primary key default gen_random_uuid(), relationship_id uuid references relationships on delete cascade, event jsonb, status text default 'pending', created_at timestamptz default now());
-- RLS: user_id = auth.uid() on every table (via a join for the child tables).
-- Values change only through security-definer functions apply_event() and apply_correction().
```
**Scope:** one relationship per user × character × universe × persona. Different universes never share values; several chats in the same universe do.

## Prompt context (built on the server every turn; ~150–200 tokens; after the character card, before memories)
```
[relationship — set by the app, read-only]
stage: Wary Acquaintances
type: Let the story decide — do not assume romance
trust 32 (cautious), affection 22 (polite warmth), attraction 6, tension 14 (mild)
pacing: slow burn — change openness gradually; no sudden confessions
play it like this:
- Shares facts and plans, but not feelings.
- Shows warmth through small actions more than words.
- Still a little wary after recent friction; avoids sore subjects.
- Shows no romantic interest; fondness stays platonic for now.
never contradict:
- You are not related to Vesper.
latest turning point: You gave your word about the letters
you may propose ONE relationship_event {kind, reason}; the app decides whether it counts.
```
Behaviour lines come from deterministic value bands (the same tables the journal displays), so what the user reads is exactly what the model gets. The bands are in `behaviorLines()` in `prototype/Main.dc.html`.

## Model output contract
```json
{ "relationship_event": { "kind": "vulnerability_shared", "actor": "character",
  "evidence": "I haven't shown that to anyone", "reason": "Vesper showed the logbook" } }
```
Numeric fields are ignored. Unknown kinds, missing evidence, or a second event in one reply are discarded and logged.

## Edge cases
- **Rewrite / alts:** a character-side event attaches to the visible alt, and switching alts re-evaluates it. User-side events never change.
- **Deleted chat:** its events stay in the timeline marked "from a deleted chat".
- **Corrections:** saved as a `user` event holding the diff; that becomes the new baseline. **Undo** writes a reversing event linked by `undone_by`; the original is struck through, never deleted.
- **Type change:** switching to Platonic or Family sets attraction to n/a in prompts and caps romance stages; history is kept.
- **Safety:** relationship state never unlocks content the account settings don't allow.

## Reference implementation
In `prototype/Main.dc.html`, see `runEngine`, `stageFor`, `behaviorLines`, `promptCtx`, `seedRel`, `undoEntry` and `acceptPending`. They are a client-side simulation of the rules above. Port that logic to the edge function, not to Flutter.
