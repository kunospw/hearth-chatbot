# Hearth — AI roleplay / creative-writing app (web)

Hearth is a dark-first AI character roleplay and creative-writing app.
Core loop: **open the app → choose a character → start roleplaying.**

This repo is a **pnpm monorepo**: a Next.js web app (`apps/web`) on top of the
existing Supabase backend (`supabase/`). It was migrated from a Flutter app;
the Flutter sources live in git history and on `main` prior to the migration.

## Stack
- **Frontend:** Next.js (App Router) + React + TypeScript + Tailwind v4, in
  `apps/web`. Self-hosted as a standalone Node server behind Caddy (`DEPLOY.md`).
- **Backend (unchanged):** Supabase — Postgres + RLS, Auth, Storage
  (`portraits`), and edge functions `chat_turn` / `apply_correction` /
  `suggest_replies` (Deno/TypeScript) in `supabase/`.
- **Model:** called only from the edge functions (`OLLAMA_API_KEY` +
  `models.ollama_model`); never from the browser. Pick an adult-content-
  friendly provider.

## Source of truth
- `docs/SPEC.md` — tokens, type, spacing, components, navigation, screens,
  states, interaction rules (the design the UI follows).
- `docs/RELATIONSHIP_ENGINE.md` — the journal, deterministic engine, SQL
  schema and prompt/model contract (lives server-side).
- `docs/UX_REVIEW.md` — journeys and acceptance checks.
- `prototype/*.dc.html` — behaviour and copy reference, not code.
- `supabase/README.md` — backend deploy and model config.

## Non-negotiable design rules (Midnight Editorial)
- Charcoal surfaces; burgundy `#9A3349` is a **fill only**; rose ink `#E9A0AE`
  for links and focus. Newsreader for story/display, Figtree for UI.
- Read colours/sizes/radii from the design tokens in
  `apps/web/app/globals.css` (and the `.t-*` text roles). Never hard-code hex.
- AI replies are full-width prose; only the user's messages are bubbles.
- Relationship values are owned by the backend. The model only *proposes* an
  event; the server validates and persists it. Writes go through the edge
  functions, never from the client.
- Touch targets: 48px primary, ≥44px inline.

## Architecture (`apps/web`)
- **Data seam** (`lib/`): `supabase/` (browser + server `@supabase/ssr`
  clients, env), `backend/` (`BackendApi` = select/upsert/update/delete/rpc/
  invoke/stream/uploadPortrait with error mapping + SSE parser, row<->model
  mappers, ARGB colour), `repositories/` (RLS-scoped per table), `domain/`
  (models). Mirrors the Flutter backend one-to-one.
- **Chat** (`lib/chat/`): `controller.ts` (ChatController: send/continue/
  rewrite/retry/stop/setAlt/edit over a UI-owned message store, throttled
  streaming, AbortController stop), `reply.ts` (`streamChatTurn` SSE consumer),
  `preview-reply.ts` (local canned replies for signed-out preview),
  `throttler.ts`. Roleplay parsing in `lib/roleplay/parse.ts`.
- **Relationship** (`lib/relationship/`): snapshot types + parser and the read
  path (`ensure_relationship` / `relationship_snapshot`), plus
  `apply_correction`.
- **UI**: `components/` (providers: session/theme/prefs; `ui/` primitives;
  feature components for chat, characters, library, relationship, chats).
  Routes in `app/`: tabbed screens in the `(app)` group (Characters, Chats,
  Library, Settings); full-screen routes outside it or under `/characters/*`
  (detail, editor, journal) and `/chat/*`.
- **Preview mode:** with no `NEXT_PUBLIC_SUPABASE_*` env the app runs signed
  out on sample data (`lib/sample/`) and a local reply source, so the UI works
  before a backend is connected. Signed in, the same screens use real data.
- **Age gate:** a hard 18+ wall in the root layout (content gate, not legal
  age verification — see `DEPLOY.md`).

## Commands
```
pnpm install
pnpm --filter web dev          # http://localhost:3000
pnpm --filter web typecheck    # tsc --noEmit (must be clean)
pnpm --filter web lint
pnpm --filter web test         # vitest unit tests
pnpm --filter web build        # standalone output for deploy
# backend regression (from supabase/):
cd supabase && npm test
```

## Deploy
See `DEPLOY.md` (self-host on an adult-tolerant VPS behind Caddy; Supabase
cloud backend; `NEXT_PUBLIC_*` are baked at build time).

## Still open (product, not code)
- Choose the adult-content-friendly model/provider and set `models.ollama_model`.
- Payments + subscription tiers (adult-friendly processor) and real age
  verification for regulated regions — a later phase.
