// POST /functions/v1/suggest_replies  (see _shared/suggest.ts)
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import { errorResponse } from '../_shared/chat_turn.ts';
import { CORS_HEADERS, bearerToken, withCors } from '../_shared/http.ts';
import { OllamaClient } from '../_shared/ollama.ts';
import { SupabaseStore } from '../_shared/supabase_store.ts';
import { handleSuggest } from '../_shared/suggest.ts';

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});
const store = new SupabaseStore(admin as never);
const llm = new OllamaClient({ apiKey: Deno.env.get('OLLAMA_API_KEY') ?? '' });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return withCors(errorResponse(405, 'method_not_allowed', 'POST only.'));
  // Ask Supabase Auth who this token belongs to; never trust the token's own claims.
  const token = bearerToken(req.headers.get('authorization'));
  const { data: auth } = token ? await admin.auth.getUser(token) : { data: { user: null } };
  const userId = auth.user?.id ?? null;
  if (userId === null) return withCors(errorResponse(401, 'unauthorized', 'Sign in first.'));
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return withCors(errorResponse(400, 'bad_request', 'Send JSON.'));
  }
  return withCors(await handleSuggest(body, userId, { store, llm }));
});
