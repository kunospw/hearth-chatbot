-- Starting points (migrations/20260101000900_starting_point.sql): a new
-- relationship begins at its character's starting point, and only the server
-- can start one over. Same helpers as 10_rls_test.sql (pg_temp is per session).

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

create function pg_temp.fails(sql text) returns boolean language plpgsql as $$
begin
  execute sql;
  return false;
exception when others then
  return true;
end $$;

create function pg_temp.check(name text, ok boolean) returns void language plpgsql as $$
begin
  if ok is not true then raise exception 'FAILED: %', name; end if;
  raise notice 'ok: %', name;
end $$;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000c', 'c@example.com');

select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
insert into public.characters (id, user_id, name, first, initial, tile_color, ink_color, starting_point) values
  ('20000000-0000-0000-0000-0000000000c1', auth.uid(), 'Mara Quill', 'Mara', 'M', 1, 2, 'together'),
  ('20000000-0000-0000-0000-0000000000c2', auth.uid(), 'Bo Lind', 'Bo', 'B', 1, 2, 'friends'),
  ('20000000-0000-0000-0000-0000000000c3', auth.uid(), 'Ada Lind', 'Ada', 'A', 1, 2, 'family'),
  ('20000000-0000-0000-0000-0000000000c4', auth.uid(), 'Rook Vane', 'Rook', 'R', 1, 2, 'rivals');
insert into public.characters (id, user_id, name, first, initial, tile_color, ink_color) values
  ('20000000-0000-0000-0000-0000000000c5', auth.uid(), 'Wren', 'Wren', 'W', 1, 2);

select pg_temp.check('a character begins as Just met unless you pick another starting point',
  (select starting_point from public.characters where id = '20000000-0000-0000-0000-0000000000c5') = 'strangers');
select pg_temp.check('an unknown starting point is refused',
  pg_temp.fails($q$update public.characters set starting_point = 'pen-pals' where id = '20000000-0000-0000-0000-0000000000c5'$q$));
select pg_temp.check('the starting point picked in the editor is stored with the character',
  (select starting_point from public.characters where id = '20000000-0000-0000-0000-0000000000c1') = 'together');

create temp table t_snaps as
  select c.starting_point as sp,
         public.ensure_relationship(c.id, (select id from public.personas where user_id = auth.uid() and is_default)) as s
    from public.characters c
   where c.user_id = auth.uid();
grant select on t_snaps to authenticated, service_role;

select pg_temp.check('Just met: Acquaintances on the friendship arc, slow burn, the old defaults',
  (select s ->> 'startingPoint' = 'strangers' and s ->> 'type' = 'undecided' and s ->> 'pacing' = 'slow'
          and (s ->> 'stageIdx')::int = 1 and s -> 'stages' ->> 1 = 'Acquaintances'
          and (s #>> '{values,trust}')::numeric = 20 and (s #>> '{values,affection}')::numeric = 15
     from t_snaps where sp = 'strangers'));
select pg_temp.check('Friends: the Friends stage, romance left to the story',
  (select s ->> 'startingPoint' = 'friends' and s ->> 'type' = 'undecided' and s ->> 'pacing' = 'balanced'
          and (s ->> 'stageIdx')::int = 3 and s -> 'stages' ->> 3 = 'Friends'
          and (s #>> '{values,trust}')::numeric = 55 and (s #>> '{values,affection}')::numeric = 55
     from t_snaps where sp = 'friends'));
select pg_temp.check('Together: a romantic couple at Happy Together on the Couple arc',
  (select s ->> 'startingPoint' = 'together' and s ->> 'type' = 'romantic' and s ->> 'pacing' = 'balanced'
          and (s ->> 'stageIdx')::int = 4 and s -> 'stages' ->> 0 = 'On the Rocks'
          and s -> 'stages' ->> 4 = 'Happy Together' and s ->> 'romanticFrom' is null
          and (s #>> '{values,trust}')::numeric = 70 and (s #>> '{values,affection}')::numeric = 75
          and (s #>> '{values,attraction}')::numeric = 70 and (s #>> '{values,tension}')::numeric = 0
     from t_snaps where sp = 'together'));
select pg_temp.check('Family: close family, romance off',
  (select s ->> 'type' = 'familial' and (s ->> 'stageIdx')::int = 4 and s -> 'stages' ->> 4 = 'Close'
          and (s #>> '{values,affection}')::numeric = 70
     from t_snaps where sp = 'family'));
select pg_temp.check('Rivals: the Rivals stage with real tension, slow burn',
  (select s ->> 'type' = 'rivalrous' and s ->> 'pacing' = 'slow' and (s ->> 'stageIdx')::int = 0
          and s -> 'stages' ->> 0 = 'Rivals' and (s #>> '{values,tension}')::numeric = 45
     from t_snaps where sp = 'rivals'));
select pg_temp.check('a new relationship has an empty timeline and no facts',
  (select bool_and(jsonb_array_length(s -> 'events') = 0 and jsonb_array_length(s -> 'facts') = 0) from t_snaps));

update public.characters set starting_point = 'rivals' where id = '20000000-0000-0000-0000-0000000000c2';
select pg_temp.check('editing the character later leaves an existing relationship alone',
  (public.ensure_relationship('20000000-0000-0000-0000-0000000000c2',
     (select id from public.personas where user_id = auth.uid() and is_default)) ->> 'startingPoint') = 'friends');
select pg_temp.check('the app cannot change where a relationship started',
  pg_temp.fails($q$update public.relationships set starting_point = 'together'$q$));

select pg_temp.as_server();
select pg_temp.check('the server can start a relationship over',
  public.commit_relationship(
    (select (s ->> 'id')::uuid from t_snaps where sp = 'friends'),
    '00000000-0000-0000-0000-00000000000c', 0, '{"startingPoint": "together", "type": "romantic"}'
  ) ->> 'startingPoint' = 'together');
select pg_temp.check('a starting point the database does not know is refused',
  pg_temp.fails(format($q$select public.commit_relationship(%L, %L, 1, '{"startingPoint": "pen-pals"}')$q$,
    (select s ->> 'id' from t_snaps where sp = 'friends'), '00000000-0000-0000-0000-00000000000c')));
