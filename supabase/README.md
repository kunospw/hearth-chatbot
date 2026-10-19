# Hearth backend (Supabase + Ollama Cloud)

```
supabase/
  migrations/                 the database (tables, row-level security, functions)
  functions/
    chat_turn/                one turn of a conversation: judge → prompt → stream → validate
    apply_correction/         everything you can do from the relationship journal
    _shared/                  engine, prompt builder, Ollama client, handlers (plain TypeScript)
  tests/                      SQL tests, engine golden tests, round trip through real SQL
```

## What runs where

| | |
|---|---|
| **The app** | Holds only the project URL, the publishable (anon) key and your own session. It reads and edits *your* rows (row-level security). It never sees the model key and never writes a relationship number. |
| **`chat_turn`** (edge function) | Verifies who you are, loads your conversation, character, persona and memories, runs the relationship engine on your new message, counts the reply against the model's daily free replies, builds the prompt (with the relationship block), streams the reply from Ollama Cloud, then validates the one event the model may propose and saves it. |
| **`apply_correction`** (edge function) | Undo, approve/dismiss a suggestion, your own corrections, type, pacing, stages, facts. The engine decides; the app only asks. |
| **Postgres** | `relationships*` tables are readable by you but have **no** write policy: only the server (service role, through `commit_relationship()`) can change them. |

The engine in `functions/_shared/engine/` is a TypeScript port of
`lib/features/relationship/domain/`. The Dart engine is the reference: both run
the scenarios in `tests/golden/scenarios.json` and must give identical results.

## One-time setup (you do these)

Everything below needs *your* accounts, so I haven't run it.

1. **Create a project** at <https://supabase.com/dashboard> (any region). Note the
   *Project URL*, the *publishable / anon key* (Settings → API) and the
   *project ref* (the `xyz` in `https://xyz.supabase.co`).
2. **Email sign-in**: Authentication → Providers → Email. For a personal app,
   switch **"Confirm email" off** so a new account can sign in at once (otherwise
   the app tells you to open the link in your email first).
3. **Log in and link the CLI** (needs Node; nothing to install globally):
   ```
   npx supabase login
   npx supabase link --project-ref <your project ref>
   ```
4. **Create the database**:
   ```
   npx supabase db push
   ```
5. **Give the functions your Ollama key** (a secret: it is never put in the app,
   the repo, or `--dart-define`):
   ```
   npx supabase secrets set OLLAMA_API_KEY=<your key from ollama.com/settings/keys>
   ```
6. **Deploy the functions**:
   ```
   npx supabase functions deploy chat_turn
   npx supabase functions deploy apply_correction
   ```
7. **Pick the real models.** The app shows friendly names (Ember, Lumen, Atlas
   Pro); the table `models` maps each to an Ollama Cloud model. Ollama renames
   and retires cloud models, so check what exists *now* and edit the column
   `ollama_model` in the dashboard (Table editor → `models`):
   ```
   curl https://ollama.com/api/tags -H "Authorization: Bearer $OLLAMA_API_KEY"
   ```
   The seeded names are placeholders. Set `daily_free_replies` (or leave it
   empty for no limit) and `busy` as you like. A wrong name shows up in the app as
   "This model is not available right now".

## Running the app against it

```
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co ^
            --dart-define=SUPABASE_ANON_KEY=<publishable key>
flutter build apk --debug --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

(`^` is the Windows continuation; on bash use `\`.) Without the two defines the
app runs on built-in sample data, with no sign-in.

First run: create an account on the sign-in screen, then on an empty home tap
**Meet the sample characters** (or Settings → Your data → Add the sample stories).

## Mature content

Settings → Roleplay → **Mature content** (off by default) is stored on your
profile. It changes one paragraph of the server's prompt (`contentPolicy()` in
`functions/_shared/prompt.ts`). The rule that every character is an adult, and
that nothing sexual involves anyone under 18, is always in the prompt and is not
connected to any setting. Whether a given model follows these instructions, and
what Ollama's own terms allow, is up to the model and to you: test the models you
choose.

## Tests

```
bash supabase/tests/run.sh          # needs Docker: SQL + RLS tests, then the engine through the real SQL
cd supabase && npm test             # engine goldens, prompt, handlers, Ollama stream (no Docker needed)
flutter test test/engine_golden_test.dart   # the Dart engine against the same goldens
```

If you change the engine's behaviour on purpose: change the Dart engine, run
`GENERATE_GOLDEN=1 flutter test test/engine_golden_test.dart` to rewrite
`tests/golden/expected.json`, then change the TypeScript port until
`npm test` passes again. If you change the JSON the server sends, regenerate
`tests/golden/snapshot.json` (`WRITE_FIXTURE=1 node --test tests/snapshot_fixture.test.ts`)
and check `test/relationship_wire_test.dart`.

## Things worth knowing

- **Daily free replies reset at 00:00 UTC** (the app text still says 07:00 in sample mode).
- **Streaming on the web** (Chrome) works through `fetch`; on Android it is a normal streamed request.
- Messages are loaded in full when the app opens. That is fine for personal use; very long histories would want paging.
- A restored (Undo) memory goes to the end of its list after a reload (its position is not stored).
- Character **drafts** are still kept on the device only.
- `OLLAMA_API_KEY` missing → every reply fails with "The model had a problem". Check `npx supabase functions logs chat_turn`.
