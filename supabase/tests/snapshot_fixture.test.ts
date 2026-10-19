// The wire format between server and app. The server's snapshot (what
// relationship_snapshot() and every chat_turn / apply_correction answer carry)
// is written to tests/golden/snapshot.json; test/relationship_wire_test.dart
// parses that same file in Dart. If the format changes this test fails until
// the file is regenerated (WRITE_FIXTURE=1 node --test tests/snapshot_fixture.test.ts)
// and the Dart test is looked at.
import { readFileSync, writeFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { relationshipToJson } from '../functions/_shared/engine/models.ts';
import { run, type Json } from './support/scenario_runner.ts';

const path = new URL('./golden/snapshot.json', import.meta.url);
const scenarios: Json[] = JSON.parse(readFileSync(new URL('./golden/scenarios.json', import.meta.url), 'utf8'));

function build(): Json {
  const base = scenarios.find((s) => s.name.startsWith('manual pacing'))!;
  const sc: Json = {
    ...base,
    setup: { ...base.setup, facts: [{ text: 'You and Vesper are siblings.', locked: true }] },
    // a promise (suggested), accepted, then another suggestion left waiting
    steps: base.steps.slice(0, 3),
  };
  const r = run(sc).final;
  return relationshipToJson({ ...r, id: 'rel-1', characterId: 'char-1', personaId: 'persona-1', version: 7 });
}

test('the committed snapshot fixture is what the server produces', () => {
  const now = JSON.parse(JSON.stringify(build()));
  if (process.env.WRITE_FIXTURE === '1') writeFileSync(path, JSON.stringify(now, null, 2) + '\n');
  const committed = JSON.parse(readFileSync(path, 'utf8'));
  assert.deepEqual(committed, now);
});

test('the fixture has the parts the app reads', () => {
  const j = JSON.parse(readFileSync(path, 'utf8'));
  assert.equal(j.pending.length, 1);
  assert.ok(j.events.some((e: Json) => e.source === 'approved'));
  assert.equal(j.facts[0].tags[0], 'family');
  assert.equal(j.version, 7);
});
