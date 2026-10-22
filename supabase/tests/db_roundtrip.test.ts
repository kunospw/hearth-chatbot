// Every golden scenario, end to end through the real SQL: the engine computes a
// step, diffRelationship() makes the patch, commit_relationship() applies it in
// Postgres, and the snapshot that comes back must equal the engine's own state.
//
// Needs the throwaway database that tests/run.sh starts (it sets
// HEARTH_PG_CONTAINER). Without it this file is skipped.
import { createHash, randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { diffRelationship, isEmptyPatch } from '../functions/_shared/engine/persist.ts';
import { STARTING_POINTS, relationshipFromJson } from '../functions/_shared/engine/models.ts';
import { startingRelationship } from '../functions/_shared/engine/bands.ts';
import { normState, run, type Json } from './support/scenario_runner.ts';

const container = process.env.HEARTH_PG_CONTAINER;
const scenarios: Json[] = JSON.parse(readFileSync(new URL('./golden/scenarios.json', import.meta.url), 'utf8'));

function psql(sql: string): string {
  const r = spawnSync('docker', ['exec', '-i', container!, 'psql', '-U', 'postgres', '-At', '-q', '-v', 'ON_ERROR_STOP=1'], {
    input: sql,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  if (r.status !== 0) throw new Error(`psql failed: ${r.stderr}\n${sql.slice(0, 600)}`);
  return r.stdout.trim();
}

const q = (s: string): string => `'${s.replaceAll("'", "''")}'`;
const jsonLit = (v: unknown): string => `$j$${JSON.stringify(v)}$j$::jsonb`;

/** A stable uuid for a scenario label ("m3", "c1"), unique per scenario like real message ids. */
const labels = new Map<string, string>();
const reverse = new Map<string, string>();
let scenarioName = '';
function uuidFor(label: string): string {
  const h = createHash('sha1').update(`hearth:${scenarioName}:${label}`).digest('hex');
  const id = `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-a${h.slice(17, 20)}-${h.slice(20, 32)}`;
  labels.set(label, id);
  reverse.set(id, label);
  return id;
}
const unmap = (x: string): string => reverse.get(x) ?? x;

const USER = '99999999-0000-0000-0000-000000000001';

test('database round trip: every golden scenario', { skip: container ? false : 'needs HEARTH_PG_CONTAINER (run tests/run.sh)' }, () => {
  psql(`insert into auth.users (id, email) values (${q(USER)}, 'roundtrip@example.com') on conflict do nothing;`);
  const persona = psql(`select id from public.personas where user_id = ${q(USER)} and is_default;`);

  for (const sc of scenarios) {
    scenarioName = sc.name;
    const charId = randomUUID();
    psql(
      `insert into public.characters (id, user_id, name, first, initial, tile_color, ink_color)
       values (${q(charId)}, ${q(USER)}, ${q(sc.name)}, 'Vesper', 'V', 1, 2);`,
    );
    const relId = randomUUID();
    const factIds: string[] = [];
    const initial = run(
      { ...sc, steps: [] },
      { relationshipId: relId, factId: () => { const id = randomUUID(); factIds.push(id); return id; } },
    ).initial;
    initial.characterId = charId;
    initial.personaId = persona;

    // The starting point, as ensure_relationship() + the setup would leave it.
    psql(
      `insert into public.relationships (id, user_id, character_id, persona_id, starting_point, type, pacing, trust,
         affection, attraction, tension, stage_idx, romantic_from)
       values (${q(relId)}, ${q(USER)}, ${q(charId)}, ${q(persona)}, ${q(initial.startingPoint)}, ${q(initial.type)},
         ${q(initial.pacing)}, ${initial.values.trust}, ${initial.values.affection}, ${initial.values.attraction},
         ${initial.values.tension}, ${initial.stageIdx}, ${initial.romanticFrom ?? 'null'});` +
        initial.stages.map((n, i) => `insert into public.relationship_stages values (${q(relId)}, ${i}, ${q(n)});`).join('') +
        initial.facts
          .map((f) => `insert into public.relationship_facts (id, relationship_id, text, locked, tags)
                       values (${q(f.id)}, ${q(relId)}, ${q(f.text)}, ${f.locked}, ${f.tags.length ? `array[${f.tags.map(q).join(',')}]` : "'{}'"});`)
          .join(''),
    );

    let version = 0;
    run(sc, {
      relationshipId: relId,
      newId: () => randomUUID(),
      mapLabel: uuidFor,
      factId: (i) => factIds[i],
      onStep: ({ index, op, step, prev, next }) => {
        const where = `${sc.name} · step ${index} (${op})`;
        let snap: Json;
        const patch = diffRelationship(prev, next);
        if (!isEmptyPatch(patch)) {
          const out = psql(
            `select public.commit_relationship(${q(relId)}, ${q(USER)}, ${version}, ${jsonLit(patch)});`,
          );
          snap = JSON.parse(out);
          version += 1;
          assert.equal(snap.version, version, `${where}: version`);
        } else {
          snap = JSON.parse(psql(`select public.relationship_snapshot(${q(relId)});`));
        }
        if (op === 'deleteChat') {
          // What the conversations delete trigger does (tested in 10_rls_test.sql).
          snap = JSON.parse(
            psql(`update public.relationship_events set from_deleted_chat = true where conversation_id = ${q(labels.get(step.conv)!)};
                  select public.relationship_snapshot(${q(relId)});`).split('\n').pop()!,
          );
        }
        const fromDb = relationshipFromJson(snap);
        assert.deepEqual(normState(fromDb, unmap), normState(next, unmap), where);
      },
    });
  }
});

test('database: a new relationship begins at its character\'s starting point, as the engine does', { skip: container ? false : 'needs HEARTH_PG_CONTAINER (run tests/run.sh)' }, () => {
  psql(`insert into auth.users (id, email) values (${q(USER)}, 'roundtrip@example.com') on conflict do nothing;`);
  const persona = psql(`select id from public.personas where user_id = ${q(USER)} and is_default;`);
  for (const start of STARTING_POINTS) {
    const charId = randomUUID();
    psql(
      `insert into public.characters (id, user_id, name, first, initial, tile_color, ink_color, starting_point)
       values (${q(charId)}, ${q(USER)}, ${q(`Start ${start}`)}, 'Mara', 'M', 1, 2, ${q(start)});`,
    );
    const snap = JSON.parse(psql(`select public.ensure_relationship_for(${q(USER)}, ${q(charId)}, ${q(persona)});`));
    const fromDb = relationshipFromJson(snap);
    const want = startingRelationship({ id: fromDb.id, characterId: charId, personaId: persona, start });
    assert.deepEqual(normState(fromDb), normState(want), start);
  }
});
