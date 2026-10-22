-- Starting points: where the story between you and a character begins.
--
--   strangers ("Just met") · friends · together · family · rivals
--
-- A character carries the one picked in the editor; every new relationship
-- with them begins there. A relationship carries the one it began at (or was
-- started over from in the journal, through apply_correction), and the prompt
-- tells the model, so a couple or old friends never play a first meeting.
-- The table of kinds, pacings, values and stage arcs is the engines'
-- `startingSetups` (relationship_bands.dart / bands.ts); keep all three equal
-- (tests/db_roundtrip.test.ts checks this one against bands.ts).

alter table public.characters
  add column starting_point text not null default 'strangers'
  check (starting_point in ('strangers', 'friends', 'together', 'family', 'rivals'));

alter table public.relationships
  add column starting_point text not null default 'strangers'
  check (starting_point in ('strangers', 'friends', 'together', 'family', 'rivals'));

-- ── create on first use, at the character's starting point ────────────────
-- Still cannot set a value the app chose: the numbers come from the fixed
-- table below, picked by the character's starting point.
create or replace function public.ensure_relationship_for(p_user uuid, p_character uuid, p_persona uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uni uuid;
  sp text;
  rid uuid;
  names text[];
  i int;
begin
  if p_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select universe_id, starting_point into uni, sp from public.characters where id = p_character and user_id = p_user;
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
    insert into public.relationships (user_id, character_id, universe_id, persona_id, starting_point,
                                      type, pacing, trust, affection, attraction, tension, stage_idx)
    select p_user, p_character, uni, p_persona, sp,
           s.type, s.pacing, s.trust, s.affection, s.attraction, s.tension, s.stage_idx
      from (values
        ('strangers', 'undecided', 'slow',     20, 15,  0,  0, 1),
        ('friends',   'undecided', 'balanced', 55, 55,  0,  0, 3),
        ('together',  'romantic',  'balanced', 70, 75, 70,  0, 4),
        ('family',    'familial',  'balanced', 65, 70,  0,  0, 4),
        ('rivals',    'rivalrous', 'slow',     15, 15,  0, 45, 0)
      ) as s(id, type, pacing, trust, affection, attraction, tension, stage_idx)
     where s.id = sp
    returning id into rid;
    names := case sp
      when 'together' then array['On the Rocks', 'Drifting Apart', 'Mending', 'Steady', 'Happy Together', 'Deeply in Love']
      when 'family' then array['Estranged', 'Distant', 'Thawing', 'Reconnecting', 'Close', 'Unbreakable']
      when 'rivals' then array['Rivals', 'Grudging Respect', 'Uneasy Truce', 'Reluctant Allies', 'Trusted Rival', 'Partners']
      else array['Strangers', 'Acquaintances', 'Allies', 'Friends', 'Close Friends', 'Found Family']
    end;
    for i in 1 .. array_length(names, 1) loop
      insert into public.relationship_stages (relationship_id, idx, name) values (rid, i - 1, names[i]);
    end loop;
  end if;
  return public.relationship_snapshot(rid);
end $$;

-- ── the snapshot and the commit carry it too ──────────────────────────────
-- As in 20260101000200_functions.sql, plus `startingPoint` in the snapshot and
-- as a commit patch key (set by apply_correction's set_starting_point).
create or replace function public.relationship_snapshot(p_id uuid) returns jsonb
language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'id', r.id,
    'characterId', r.character_id,
    'personaId', r.persona_id,
    'universeId', r.universe_id,
    'startingPoint', r.starting_point,
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

create or replace function public.commit_relationship(
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
    starting_point = coalesce(p_patch ->> 'startingPoint', r.starting_point),
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
