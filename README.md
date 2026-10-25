# Hearth

A dark-first AI character **roleplay / creative-writing** web app.
Core loop: open the app → choose a character → start roleplaying.

Monorepo: a **Next.js** app (`apps/web`) on top of a **Supabase** backend
(`supabase/`). Migrated from Flutter (the Flutter sources remain in git
history).

## Quick start

```bash
pnpm install
pnpm --filter web dev      # http://localhost:3000
```

Without Supabase keys the app runs in a **signed-out preview** on sample data
(no backend needed). To connect a backend, copy `apps/web/.env.local.example`
to `apps/web/.env.local` and fill in your Supabase URL + anon key, then deploy
the backend as in `supabase/README.md`.

## Layout
- `apps/web` — the Next.js frontend (App Router, TypeScript, Tailwind v4).
- `supabase/` — Postgres schema + RLS, Auth, Storage, and the edge functions
  (`chat_turn`, `apply_correction`, `suggest_replies`). Unchanged by the
  migration.
- `docs/` — SPEC, relationship engine, UX review (the source of truth).
- `prototype/` — interactive design canvas (reference).
- `assets/`, `marketing/` — brand assets and marketing kit.
- `deploy/`, `DEPLOY.md` — self-host config (Caddy + systemd + Docker) and the
  deployment guide.

## Scripts
`pnpm --filter web {dev,build,start,lint,typecheck,test}`. See `CLAUDE.md` for
architecture and the design rules, and `DEPLOY.md` to ship it.
