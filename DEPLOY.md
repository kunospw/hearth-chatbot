# Deploying Hearth (web)

Hearth is a Next.js app (`apps/web`) on top of the existing Supabase backend
(`supabase/`). The frontend is **self-hosted** on an adult-content-tolerant VPS
behind Caddy; Supabase cloud owns the database, auth, storage and the edge
functions; the model runs behind those edge functions.

## 1. Backend (Supabase) — once

From `supabase/` (see `supabase/README.md` for detail):

```bash
npx supabase login
npx supabase link --project-ref <your-ref>
npx supabase db push                      # apply migrations (schema + RLS)
npx supabase functions deploy chat_turn
npx supabase functions deploy apply_correction
npx supabase functions deploy suggest_replies
npx supabase secrets set OLLAMA_API_KEY=<key>   # model provider key
```

- Pick an **adult-content-friendly model/provider** and set each model's
  `ollama_model` column in the `models` table (the seeded names are
  placeholders — confirm against the provider's model list).
- In Supabase Auth, set the site URL / redirect URLs to your domain. For a
  smoother launch you can turn off "Confirm email".
- CORS: confirm `supabase/functions/_shared/http.ts` allows your web origin.

## 2. Frontend env (baked at BUILD time)

`NEXT_PUBLIC_*` values are inlined when the app is built, not read at runtime.
Create `apps/web/.env.production` (or export the vars) **before** building:

```
NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon key>
```

## 3. Build and run (systemd + Caddy)

On the VPS, with Node 20+ and pnpm, repo at `/opt/hearth`:

```bash
cd /opt/hearth
pnpm install
pnpm --filter web build
# standalone server needs the static assets copied next to it:
cp -r apps/web/.next/static apps/web/.next/standalone/apps/web/.next/static
```

Install the service and proxy:

```bash
sudo cp deploy/hearth-web.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now hearth-web
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile   # edit the domain first
sudo systemctl reload caddy
```

The Next server listens on `127.0.0.1:3000`; Caddy terminates TLS and proxies
to it. The chat SSE stream runs **browser → Supabase** directly, so Caddy needs
no streaming tuning.

### Docker alternative

```bash
docker build -f apps/web/Dockerfile \
  --build-arg NEXT_PUBLIC_SUPABASE_URL=... \
  --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY=... \
  -t hearth-web .
docker run -p 127.0.0.1:3000:3000 hearth-web
```

## 4. Pre-launch (adult product)

- **Host:** use an adult-content-tolerant VPS/provider (many managed hosts'
  AUPs prohibit explicit content). The built-in 18+ gate is a content gate,
  not legal age verification.
- **Age verification:** for the UK (OSA) and some US states, add a real
  age-verification vendor.
- **Payments:** not Stripe/PayPal — use an adult-friendly processor
  (CCBill/Segpay/Verotel) or crypto. (Subscription tiers are a later phase.)

## 5. Checks

```bash
pnpm --filter web typecheck
pnpm --filter web lint
pnpm --filter web test        # unit tests (parser, mappers, color, relationship)
pnpm --filter web build
# backend regression:
cd supabase && npm test
```
