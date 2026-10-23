#!/usr/bin/env bash
# Vercel's build step (see vercel.json): the web app, connected to your
# Supabase project. SUPABASE_URL and SUPABASE_ANON_KEY come from the Vercel
# project's environment variables; they are the same two values `flutter run`
# takes with --dart-define, and both are meant to ship inside the app.
set -euo pipefail
export PATH="$PWD/.flutter/bin:$PATH"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Add SUPABASE_URL and SUPABASE_ANON_KEY in Vercel (Settings → Environment Variables), then redeploy." >&2
  exit 1
fi

# The renderer (CanvasKit) is served from this site rather than Google's CDN.
flutter build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
