-- RLS and function tests. Runs as superuser, switching role with SET ROLE and
-- the JWT subject with set_config, exactly like PostgREST does.

create function pg_temp.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u::text, false);
  set role authenticated;
end $$;

create function pg_temp.as_server() returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claim.sub', '', false);
  set role service_role;
end $$;

create function pg_temp.as_admin() returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claim.sub', '', false);
end $$;

create function pg_temp.fails(sql text) returns boolean language plpgsql as $$
begin
  execute sql;
  return false;
exception when others then
  return true;
end $$;

create function pg_temp.affected(sql text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute sql;
  get diagnostics n = row_count;
  return n;
end $$;

create function pg_temp.check(name text, ok boolean) returns void language plpgsql as $$
begin
  if ok is not true then raise exception 'FAILED: %', name; end if;
  raise notice 'ok: %', name;
end $$;

-- two users
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

select pg_temp.check('signup creates a profile', (select count(*) from public.profiles) = 2);
select pg_temp.check('signup creates the Just me persona', (select count(*) from public.personas where is_default) = 2);
select pg_temp.check('adult content is off by default', not exists (select 1 from public.profiles where adult_content));

-- A creates a universe, a character, a chat and a message.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into public.universes (id, user_id, name, tile_color, description)
values ('10000000-0000-0000-0000-000000000001', auth.uid(), 'Saltmarsh', 4283000000, 'A coast');
insert into public.characters (id, user_id, name, first, initial, tile_color, ink_color, universe_id)
values ('20000000-0000-0000-0000-000000000001', auth.uid(), 'Vesper Hale', 'Vesper', 'V', 1, 2,
        '10000000-0000-0000-0000-000000000001');
insert into public.conversations (id, user_id, character_id, title)
values ('30000000-0000-0000-0000-000000000001', auth.uid(), '20000000-0000-0000-0000-000000000001', 'First');
insert into public.messages (id, conversation_id, user_id, role, alts)
values ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', auth.uid(), 'user', '["hello"]');
insert into public.memories (user_id, universe_id, category, text)
values (auth.uid(), '10000000-0000-0000-0000-000000000001', 'facts', 'The bell is cracked');

-- B cannot see or touch A's rows.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select pg_temp.check('B sees none of A''s characters', (select count(*) from public.characters) = 0);
select pg_temp.check('B sees none of A''s messages', (select count(*) from public.messages) = 0);
select pg_temp.check('B sees none of A''s memories', (select count(*) from public.memories) = 0);
select pg_temp.check('B cannot update A''s character',
  pg_temp.affected($q$update public.characters set name = 'hacked'$q$) = 0);
select pg_temp.check('B cannot delete A''s conversation',
  pg_temp.affected($q$delete from public.conversations$q$) = 0);
select pg_temp.check('B cannot insert a row as A',
  pg_temp.fails($q$insert into public.universes (user_id, name, tile_color) values ('00000000-0000-0000-0000-00000000000a', 'x', 1)$q$));
select pg_temp.check('B cannot attach a chat to A''s character',
  pg_temp.fails($q$insert into public.conversations (user_id, character_id) values (auth.uid(), '20000000-0000-0000-0000-000000000001')$q$));
select pg_temp.check('B cannot post a message into A''s chat',
  pg_temp.fails($q$insert into public.messages (conversation_id, user_id, role, alts) values ('30000000-0000-0000-0000-000000000001', auth.uid(), 'user', '["x"]')$q$));
select pg_temp.check('B cannot put a memory in A''s universe',
  pg_temp.fails($q$insert into public.memories (user_id, universe_id, category, text) values (auth.uid(), '10000000-0000-0000-0000-000000000001', 'facts', 'x')$q$));
select pg_temp.check('B cannot read the models table ollama_model column',
  pg_temp.fails($q$select ollama_model from public.models$q$));
select pg_temp.check('B can read the model list', (select count(*) from public.models) = 3);
select pg_temp.check('B cannot flip adult content on someone else',
  pg_temp.affected($q$update public.profiles set adult_content = true where id = '00000000-0000-0000-0000-00000000000a'$q$) = 0);

-- ── relationships ────────────────────────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
create temp table t_ids as
  select (select id from public.personas where user_id = auth.uid() and is_default) as persona;
grant select on t_ids to authenticated, service_role;

create temp table t_rel as
  select public.ensure_relationship('20000000-0000-0000-0000-000000000001', (select persona from t_ids)) as snap;
grant select on t_rel to authenticated, service_role;
select pg_temp.check('ensure creates a relationship with defaults',
  (select (snap ->> 'stageIdx')::int from t_rel) = 1
  and (select snap #>> '{values,trust}' from t_rel) = '20.0'
  and (select jsonb_array_length(snap -> 'stages') from t_rel) = 6);
select pg_temp.check('ensure twice returns the same relationship',
  public.ensure_relationship('20000000-0000-0000-0000-000000000001', (select persona from t_ids)) ->> 'id'
  = (select snap ->> 'id' from t_rel));
select pg_temp.check('ensure rejects a character you do not own',
  (select pg_temp.fails(format($q$select public.ensure_relationship(%L, %L)$q$,
     '20000000-0000-0000-0000-000000000009', (select persona from t_ids)))));

-- The app can read, never write.
select pg_temp.check('A can read the relationship', (select count(*) from public.relationships) = 1);
select pg_temp.check('A cannot write trust',
  pg_temp.fails($q$update public.relationships set trust = 100$q$));
select pg_temp.check('A cannot insert an event',
  pg_temp.fails($q$insert into public.relationship_events (relationship_id, category, title, source) select id, 'shift', 'x', 'user' from public.relationships$q$));
select pg_temp.check('A cannot delete facts',
  pg_temp.fails($q$delete from public.relationship_facts$q$));
select pg_temp.check('A cannot call commit_relationship',
  pg_temp.fails($q$select public.commit_relationship(gen_random_uuid(), auth.uid(), 0, '{}')$q$));
select pg_temp.check('A cannot call consume_model_reply',
  pg_temp.fails($q$select public.consume_model_reply(auth.uid(), 'ember')$q$));

select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select pg_temp.check('B sees no relationships', (select count(*) from public.relationships) = 0);
select pg_temp.check('B cannot read A''s snapshot', (select public.relationship_snapshot((select (snap ->> 'id')::uuid from t_rel))) is null);

select pg_temp.check('A cannot call the server-only ensure/snapshot helpers',
  pg_temp.fails(format($q$select public.ensure_relationship_for(%L, %L, %L)$q$, '00000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-000000000001', (select persona from t_ids)))
  and pg_temp.fails(format($q$select public.relationship_snapshot_for(%L, auth.uid())$q$, (select snap ->> 'id' from t_rel))));
select pg_temp.check('A cannot read or write model proposals', pg_temp.fails($q$select * from public.relationship_proposals$q$));

select pg_temp.as_server();
select pg_temp.check('the server can read a snapshot only for its owner',
  public.relationship_snapshot_for((select (snap ->> 'id')::uuid from t_rel), '00000000-0000-0000-0000-00000000000a') is not null
  and public.relationship_snapshot_for((select (snap ->> 'id')::uuid from t_rel), '00000000-0000-0000-0000-00000000000b') is null);
select pg_temp.check('the server can create a relationship for a user, but not for a character that is not theirs',
  (public.ensure_relationship_for('00000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-000000000001', (select persona from t_ids)) ->> 'id') = (select snap ->> 'id' from t_rel)
  and pg_temp.fails(format($q$select public.ensure_relationship_for(%L, %L, %L)$q$, '00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-000000000001', (select persona from t_ids))));
select pg_temp.check('the server can store a model proposal; the (message, version) key is unique',
  not pg_temp.fails(format($q$insert into public.relationship_proposals (message_id, alt_index, relationship_id, kind, evidence) values (%L, 0, %L, 'rescue', 'x')$q$, '40000000-0000-0000-0000-000000000001', (select snap ->> 'id' from t_rel)))
  and pg_temp.fails(format($q$insert into public.relationship_proposals (message_id, alt_index, relationship_id, kind, evidence) values (%L, 0, %L, 'rescue', 'y')$q$, '40000000-0000-0000-0000-000000000001', (select snap ->> 'id' from t_rel))));

-- ── commit (server) ──────────────────────────────────────────────────────
select pg_temp.as_server();
create temp table t_c as
  select public.commit_relationship(
    (select (snap ->> 'id')::uuid from t_rel),
    '00000000-0000-0000-0000-00000000000a', 0,
    jsonb_build_object(
      'values', jsonb_build_object('trust', 24, 'affection', 15, 'attraction', 0, 'tension', 0),
      'turn', 1,
      'recentHashes', jsonb_build_array('1|i promise'),
      'events', jsonb_build_object('insert', jsonb_build_array(jsonb_build_object(
        'id', '50000000-0000-0000-0000-000000000001', 'kindId', 'promise_made', 'category', 'shift',
        'title', 'You made a promise', 'source', 'engine', 'deltas', jsonb_build_object('trust', 4),
        'messageId', '40000000-0000-0000-0000-000000000001',
        'conversationId', '30000000-0000-0000-0000-000000000001',
        'turn', 1, 'undoable', true, 'why', 'test', 'at', '2026-01-01T12:00:00Z'))),
      'facts', jsonb_build_object('upsert', jsonb_build_array(jsonb_build_object(
        'id', '60000000-0000-0000-0000-000000000001', 'text', 'Not related', 'locked', true, 'tags', jsonb_build_array('family'))))
    )) as snap;
select pg_temp.check('commit applies values and bumps the version',
  (select snap #>> '{values,trust}' from t_c) = '24.0' and (select (snap ->> 'version')::int from t_c) = 1);
select pg_temp.check('commit stores the event and the fact',
  (select jsonb_array_length(snap -> 'events') from t_c) = 1 and (select jsonb_array_length(snap -> 'facts') from t_c) = 1);
select pg_temp.check('a stale version is rejected',
  pg_temp.fails(format($q$select public.commit_relationship(%L, %L, 0, '{}')$q$,
    (select snap ->> 'id' from t_rel), '00000000-0000-0000-0000-00000000000a')));
select pg_temp.check('another user cannot commit to it',
  pg_temp.fails(format($q$select public.commit_relationship(%L, %L, 1, '{}')$q$,
    (select snap ->> 'id' from t_rel), '00000000-0000-0000-0000-00000000000b')));
select pg_temp.check('values outside 0..100 are rejected',
  pg_temp.fails(format($q$select public.commit_relationship(%L, %L, 1, '{"values":{"trust":120}}')$q$,
    (select snap ->> 'id' from t_rel), '00000000-0000-0000-0000-00000000000a')));
select pg_temp.check('the same message and kind cannot count twice',
  pg_temp.fails(format($q$select public.commit_relationship(%L, %L, 1, %L::jsonb)$q$,
    (select snap ->> 'id' from t_rel), '00000000-0000-0000-0000-00000000000a',
    '{"events":{"insert":[{"id":"50000000-0000-0000-0000-000000000002","kindId":"promise_made","category":"shift","title":"again","source":"engine","messageId":"40000000-0000-0000-0000-000000000001","at":"2026-01-01T12:01:00Z"}]}}')));

-- An undo marks the original struck through, frees the (message, kind) slot,
-- and the same message can then count again (an edited message).
create temp table t_u as
  select public.commit_relationship(
    (select (snap ->> 'id')::uuid from t_rel),
    '00000000-0000-0000-0000-00000000000a', 1,
    jsonb_build_object(
      'values', jsonb_build_object('trust', 20),
      'events', jsonb_build_object('insert', jsonb_build_array(
        jsonb_build_object('id', '50000000-0000-0000-0000-000000000003', 'kindId', 'undo',
          'category', 'correction', 'title', 'Undid', 'source', 'undo', 'undoOf', '50000000-0000-0000-0000-000000000001',
          'deltas', jsonb_build_object('trust', -4), 'at', '2026-01-01T12:02:00Z'),
        jsonb_build_object('id', '50000000-0000-0000-0000-000000000004', 'kindId', 'promise_made',
          'category', 'shift', 'title', 'again', 'source', 'engine',
          'messageId', '40000000-0000-0000-0000-000000000001', 'at', '2026-01-01T12:03:00Z'))))) as snap;
select pg_temp.check('undo strikes the original through and keeps it',
  (select (e ->> 'undoneBy') = '50000000-0000-0000-0000-000000000003'
     from t_u, jsonb_array_elements(snap -> 'events') e where e ->> 'id' = '50000000-0000-0000-0000-000000000001'));
select pg_temp.check('events come newest first',
  (select snap -> 'events' -> 0 ->> 'id' from t_u) = '50000000-0000-0000-0000-000000000004');
select pg_temp.check('the event log keeps every row', (select jsonb_array_length(snap -> 'events') from t_u) = 3);

-- Suggestions (Manual pacing).
create temp table t_s as
  select public.commit_relationship(
    (select (snap ->> 'id')::uuid from t_rel), '00000000-0000-0000-0000-00000000000a', 2,
    jsonb_build_object('suggestions', jsonb_build_object('insert', jsonb_build_array(jsonb_build_object(
      'id', '70000000-0000-0000-0000-000000000001', 'kindId', 'appreciation', 'category', 'shift',
      'title', 'Thanks', 'deltas', jsonb_build_object('affection', 1), 'why', 'w', 'turn', 2)))))
    as snap;
select pg_temp.check('a suggestion waits as pending', (select jsonb_array_length(snap -> 'pending') from t_s) = 1);

-- Stages replace wholesale; romanticFrom null clears.
create temp table t_st as
  select public.commit_relationship(
    (select (snap ->> 'id')::uuid from t_rel), '00000000-0000-0000-0000-00000000000a', 3,
    '{"stages":["A","B","C","D","E","F"],"romanticFrom":4,"suggestions":{"delete":["70000000-0000-0000-0000-000000000001"]}}'::jsonb) as snap;
select pg_temp.check('stages replaced and romanticFrom set',
  (select snap -> 'stages' ->> 0 from t_st) = 'A' and (select (snap ->> 'romanticFrom')::int from t_st) = 4
  and (select jsonb_array_length(snap -> 'pending') from t_st) = 0);
create temp table t_st2 as
  select public.commit_relationship(
    (select (snap ->> 'id')::uuid from t_rel), '00000000-0000-0000-0000-00000000000a', 4,
    '{"romanticFrom":null}'::jsonb) as snap;
select pg_temp.check('romanticFrom can be cleared', (select snap -> 'romanticFrom' from t_st2) = 'null'::jsonb);

-- Deleting the chat keeps the events and marks them.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
delete from public.conversations where id = '30000000-0000-0000-0000-000000000001';
select pg_temp.check('events survive a deleted chat, marked',
  (select count(*) from public.relationship_events where from_deleted_chat) >= 1);
select pg_temp.check('the message went with the chat', (select count(*) from public.messages) = 0);

-- ── model usage (server) ─────────────────────────────────────────────────
select pg_temp.as_server();
select pg_temp.check('first reply counts',
  (public.consume_model_reply('00000000-0000-0000-0000-00000000000a', 'ember') ->> 'ok')::boolean);
select pg_temp.check('the real model name is returned to the server',
  public.consume_model_reply('00000000-0000-0000-0000-00000000000a', 'ember') ->> 'ollamaModel' is not null);
select pg_temp.check('a busy model says busy',
  public.consume_model_reply('00000000-0000-0000-0000-00000000000a', 'atlas') ->> 'reason' = 'busy');
select pg_temp.check('an unknown model is rejected',
  public.consume_model_reply('00000000-0000-0000-0000-00000000000a', 'nope') ->> 'reason' = 'unknown_model');
update public.models set daily_free_replies = 2 where id = 'ember';
select pg_temp.check('the limit stops further replies',
  public.consume_model_reply('00000000-0000-0000-0000-00000000000a', 'ember') ->> 'reason' = 'limit');
select public.refund_model_reply('00000000-0000-0000-0000-00000000000a', 'ember');
select pg_temp.check('a refund frees a reply',
  (public.consume_model_reply('00000000-0000-0000-0000-00000000000a', 'ember') ->> 'ok')::boolean);

select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.check('A reads own usage', (select count(*) from public.model_usage) = 1);
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select pg_temp.check('B cannot read A''s usage', (select count(*) from public.model_usage) = 0);
select pg_temp.check('B cannot change usage', pg_temp.fails($q$update public.model_usage set used = 0$q$) or
  (select count(*) from public.model_usage) = 0);

-- Portrait bucket: only your own folder.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.check('A can upload under their own folder',
  not pg_temp.fails($q$insert into storage.objects (bucket_id, name) values ('portraits', '00000000-0000-0000-0000-00000000000a/x.png')$q$));
select pg_temp.check('A cannot upload into B''s folder',
  pg_temp.fails($q$insert into storage.objects (bucket_id, name) values ('portraits', '00000000-0000-0000-0000-00000000000b/x.png')$q$));

select pg_temp.as_admin();
