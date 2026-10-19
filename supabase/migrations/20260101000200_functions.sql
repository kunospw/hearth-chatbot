-- Functions for the relationship journal and model usage.
--
--   relationship_snapshot(id)      read one relationship as JSON (RLS applies)
--   ensure_relationship(char, p)   create-on-first-use (callable by the app)
--   commit_relationship(...)       apply an engine result atomically (SERVER ONLY)
--   consume_model_reply / refund   daily free replies per model (SERVER ONLY)
--
-- The JSON shape is the one the Flutter app parses (camelCase). `source` is
-- stored as engine | model_proposal | user | undo | approved | setup and
-- exposed as engine | modelProposal | user | undo | approved | setup.

create function public._src_out(s text) returns text
language sql immutable as $$ select case s when 'model_proposal' then 'modelProposal' else s end $$;

create function public._src_in(s text) returns text
language sql immutable as $$ select case s when 'modelProposal' then 'model_proposal' else s end $$;

-- ── snapshot ──────────────────────────────────────────────────────────────
create function public.relationship_snapshot(p_id uuid) returns jsonb
language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'id', r.id,
    'characterId', r.character_id,
    'personaId', r.persona_id,
    'universeId', r.universe_id,
    'type', r.type,
    'pacing', r.pacing,
    'values', jsonb_build_object(
      'trust', r.trust, 'affection', r.affection,
      'attraction', r.attraction, 'tension', r.tension),
    'stages', coalesce((select jsonb_agg(s.name order by s.idx)
                        from public.relationship_stages s where s.relationship_id = r.id), '[]'::jsonb),
    'stageIdx', r.stage_idx,
    'stageLocked', r.stage_locked,
    'romanticFrom', r.romantic_from,
    'turn', r.turn,
    'ignored', r.ignored,
    'version', r.version,
    'recentHashes', r.recent_hashes,
    'facts', coalesce((select jsonb_agg(jsonb_build_object(
                'id', f.id, 'text', f.text, 'locked', f.locked, 'tags', to_jsonb(f.tags))
                order by f.seq)
              from public.relationship_facts f where f.relationship_id = r.id), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
                'id', e.id, 'kindId', e.kind, 'category', e.category, 'title', e.title,
                'at', e.created_at, 'why', e.why, 'source', public._src_out(e.source),
                'deltas', e.deltas, 'multipliers', e.multipliers, 'evidence', e.evidence,
                'chatTitle', e.chat_title, 'conversationId', e.conversation_id,
                'messageId', e.message_id, 'turn', e.turn,
                'stageBefore', e.stage_before, 'stageAfter', e.stage_after,
                'undoable', e.undoable, 'undoneBy', e.undone_by, 'undoOf', e.undo_of,
                'fromDeletedChat', e.from_deleted_chat)
                order by e.seq desc)
              from public.relationship_events e where e.relationship_id = r.id), '[]'::jsonb),
    'pending', coalesce((select jsonb_agg(jsonb_build_object(
                'id', p.id, 'kindId', p.kind, 'category', p.category, 'title', p.title,
                'deltas', p.deltas, 'multipliers', p.multipliers, 'why', p.why,
                'evidence', p.evidence, 'source', public._src_out(p.source),
                'chatTitle', p.chat_title, 'conversationId', p.conversation_id,
                'messageId', p.message_id, 'turn', p.turn, 'at', p.created_at)
                order by p.seq desc)
              from public.relationship_suggestions p
              where p.relationship_id = r.id and p.status = 'pending'), '[]'::jsonb)
  )
  from public.relationships r
  where r.id = p_id
$$;

-- ── create on first use ───────────────────────────────────────────────────
-- Creates the default starting point for a character and persona the user owns.
-- It cannot set a value. `ensure_relationship_for` is the server's version
-- (the edge functions know the user id from the verified token);
-- `ensure_relationship` is what the app calls.
create function public.ensure_relationship_for(p_user uuid, p_character uuid, p_persona uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uni uuid;
  rid uuid;
  names text[] := array['Strangers', 'Acquaintances', 'Allies', 'Friends', 'Close Friends', 'Found Family'];
  i int;
begin
  if p_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select universe_id into uni from public.characters where id = p_character and user_id = p_user;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.personas where id = p_persona and user_id = p_user) then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  select id into rid from public.relationships
   where user_id = p_user and character_id = p_character and persona_id = p_persona
     and universe_id is not distinct from uni;
  if rid is null then
    insert into public.relationships (user_id, character_id, universe_id, persona_id, stage_idx)
    values (p_user, p_character, uni, p_persona, 1)
    returning id into rid;
    for i in 1 .. array_length(names, 1) loop
      insert into public.relationship_stages (relationship_id, idx, name) values (rid, i - 1, names[i]);
    end loop;
  end if;
  return public.relationship_snapshot(rid);
end $$;

create function public.ensure_relationship(p_character uuid, p_persona uuid) returns jsonb
language sql security definer set search_path = public as $$
  select public.ensure_relationship_for(auth.uid(), p_character, p_persona)
$$;

-- The snapshot, but only if it belongs to p_user (null otherwise). Server only.
create function public.relationship_snapshot_for(p_id uuid, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select public.relationship_snapshot(p_id)
   where exists (select 1 from public.relationships r where r.id = p_id and r.user_id = p_user)
$$;

-- ── commit an engine result (server only) ─────────────────────────────────
-- The edge function loads a snapshot, runs the engine, and sends the changed
-- parts here. Everything happens in one transaction, guarded by `version`.
--
-- p_patch keys (all optional):
--   type, pacing, values{trust,affection,attraction,tension}, stageIdx,
--   stageLocked, romanticFrom (null clears), turn, ignored, recentHashes,
--   stages[names],
--   facts{upsert:[{id,text,locked,tags}], delete:[id]},
--   events{insert:[event, oldest first]}      -- an event with undoOf also
--                                                marks the original undone
--   suggestions{insert:[...], delete:[id]}
create function public.commit_relationship(
  p_id uuid, p_user uuid, p_expected_version integer, p_patch jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v jsonb := p_patch -> 'values';
  e jsonb;
  f jsonb;
  s jsonb;
  d text;
  idx int;
  hit int;
begin
  update public.relationships r set
    type = coalesce(p_patch ->> 'type', r.type),
    pacing = coalesce(p_patch ->> 'pacing', r.pacing),
    trust = coalesce((v ->> 'trust')::numeric, r.trust),
    affection = coalesce((v ->> 'affection')::numeric, r.affection),
    attraction = coalesce((v ->> 'attraction')::numeric, r.attraction),
    tension = coalesce((v ->> 'tension')::numeric, r.tension),
    stage_idx = coalesce((p_patch ->> 'stageIdx')::int, r.stage_idx),
    stage_locked = coalesce((p_patch ->> 'stageLocked')::boolean, r.stage_locked),
    romantic_from = case when p_patch ? 'romanticFrom' then (p_patch ->> 'romanticFrom')::int else r.romantic_from end,
    turn = coalesce((p_patch ->> 'turn')::int, r.turn),
    ignored = coalesce((p_patch ->> 'ignored')::int, r.ignored),
    recent_hashes = coalesce(p_patch -> 'recentHashes', r.recent_hashes),
    version = r.version + 1,
    updated_at = now()
  where r.id = p_id and r.user_id = p_user and r.version = p_expected_version;
  get diagnostics hit = row_count;
  if hit = 0 then
    raise exception 'version_conflict' using errcode = 'P0001';
  end if;

  if p_patch ? 'stages' then
    delete from public.relationship_stages where relationship_id = p_id;
    idx := 0;
    for d in select jsonb_array_elements_text(p_patch -> 'stages') loop
      insert into public.relationship_stages (relationship_id, idx, name) values (p_id, idx, d);
      idx := idx + 1;
    end loop;
  end if;

  for f in select * from jsonb_array_elements(coalesce(p_patch #> '{facts,upsert}', '[]'::jsonb)) loop
    insert into public.relationship_facts (id, relationship_id, text, locked, tags)
    values ((f ->> 'id')::uuid, p_id, f ->> 'text', coalesce((f ->> 'locked')::boolean, true),
            coalesce(array(select jsonb_array_elements_text(f -> 'tags')), '{}'))
    on conflict (id) do update set text = excluded.text, locked = excluded.locked, tags = excluded.tags
    where public.relationship_facts.relationship_id = p_id;
  end loop;
  delete from public.relationship_facts
   where relationship_id = p_id
     and id in (select (jsonb_array_elements_text(coalesce(p_patch #> '{facts,delete}', '[]'::jsonb)))::uuid);

  for e in select * from jsonb_array_elements(coalesce(p_patch #> '{events,insert}', '[]'::jsonb)) loop
    insert into public.relationship_events (
      id, relationship_id, conversation_id, message_id, kind, category, title, source,
      deltas, multipliers, evidence, why, chat_title, turn, stage_before, stage_after,
      undoable, undo_of, created_at)
    values (
      (e ->> 'id')::uuid, p_id, (e ->> 'conversationId')::uuid, (e ->> 'messageId')::uuid,
      e ->> 'kindId', e ->> 'category', e ->> 'title', public._src_in(e ->> 'source'),
      coalesce(e -> 'deltas', '{}'), coalesce(e -> 'multipliers', '{}'), e ->> 'evidence',
      coalesce(e ->> 'why', ''), coalesce(e ->> 'chatTitle', 'Story'), coalesce((e ->> 'turn')::int, 0),
      (e ->> 'stageBefore')::int, (e ->> 'stageAfter')::int,
      coalesce((e ->> 'undoable')::boolean, false), (e ->> 'undoOf')::uuid,
      coalesce((e ->> 'at')::timestamptz, now()));
    -- A reversing event strikes the original through (it is never deleted).
    if e ->> 'undoOf' is not null then
      update public.relationship_events set undone_by = (e ->> 'id')::uuid
       where id = (e ->> 'undoOf')::uuid and relationship_id = p_id;
    end if;
  end loop;

  for s in select * from jsonb_array_elements(coalesce(p_patch #> '{suggestions,insert}', '[]'::jsonb)) loop
    insert into public.relationship_suggestions (
      id, relationship_id, kind, category, title, deltas, multipliers, why, evidence, source,
      chat_title, conversation_id, message_id, turn, created_at)
    values (
      (s ->> 'id')::uuid, p_id, s ->> 'kindId', s ->> 'category', s ->> 'title',
      coalesce(s -> 'deltas', '{}'), coalesce(s -> 'multipliers', '{}'), coalesce(s ->> 'why', ''),
      s ->> 'evidence', public._src_in(coalesce(s ->> 'source', 'engine')),
      coalesce(s ->> 'chatTitle', 'Story'), (s ->> 'conversationId')::uuid, (s ->> 'messageId')::uuid,
      coalesce((s ->> 'turn')::int, 0), coalesce((s ->> 'at')::timestamptz, now()));
  end loop;
  delete from public.relationship_suggestions
   where relationship_id = p_id
     and id in (select (jsonb_array_elements_text(coalesce(p_patch #> '{suggestions,delete}', '[]'::jsonb)))::uuid);

  return public.relationship_snapshot(p_id);
end $$;

-- ── daily free replies (server only) ──────────────────────────────────────
create function public.consume_model_reply(p_user uuid, p_model text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  m public.models;
  n integer;
begin
  select * into m from public.models where id = p_model and enabled;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_model');
  end if;
  if m.busy then
    return jsonb_build_object('ok', false, 'reason', 'busy');
  end if;
  insert into public.model_usage as u (user_id, model_id, day, used)
  values (p_user, p_model, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, model_id, day) do update set used = u.used + 1
  where m.daily_free_replies is null or u.used < m.daily_free_replies
  returning used into n;
  if n is null then
    return jsonb_build_object('ok', false, 'reason', 'limit', 'limit', m.daily_free_replies);
  end if;
  return jsonb_build_object('ok', true, 'used', n, 'limit', m.daily_free_replies,
                            'ollamaModel', m.ollama_model);
end $$;

create function public.refund_model_reply(p_user uuid, p_model text) returns void
language sql security definer set search_path = public as $$
  update public.model_usage set used = greatest(used - 1, 0)
   where user_id = p_user and model_id = p_model and day = (now() at time zone 'utc')::date
$$;

-- Only the server (service role) may run the write functions.
revoke all on function public.commit_relationship(uuid, uuid, integer, jsonb) from public, anon, authenticated;
revoke all on function public.consume_model_reply(uuid, text) from public, anon, authenticated;
revoke all on function public.refund_model_reply(uuid, text) from public, anon, authenticated;
grant execute on function public.commit_relationship(uuid, uuid, integer, jsonb) to service_role;
grant execute on function public.consume_model_reply(uuid, text) to service_role;
grant execute on function public.refund_model_reply(uuid, text) to service_role;

revoke all on function public.ensure_relationship_for(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.relationship_snapshot_for(uuid, uuid) from public, anon, authenticated;
grant execute on function public.ensure_relationship_for(uuid, uuid, uuid) to service_role;
grant execute on function public.relationship_snapshot_for(uuid, uuid) to service_role;

revoke all on function public.ensure_relationship(uuid, uuid) from public, anon;
grant execute on function public.ensure_relationship(uuid, uuid) to authenticated;
grant execute on function public.relationship_snapshot(uuid) to authenticated, service_role;
