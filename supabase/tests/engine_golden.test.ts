// Runs the shared scenarios (tests/golden/scenarios.json) through the
// TypeScript engine and requires the exact result the Dart engine produced
// (tests/golden/expected.json, written by test/engine_golden_test.dart).
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { run, type Json } from './support/scenario_runner.ts';

const here = new URL('./golden/', import.meta.url);
const scenarios: Json[] = JSON.parse(readFileSync(new URL('scenarios.json', here), 'utf8'));
const expected: Json[] = JSON.parse(readFileSync(new URL('expected.json', here), 'utf8'));

for (const [idx, sc] of scenarios.entries()) {
  test(`golden: ${sc.name}`, () => {
    const want = expected[idx];
    assert.equal(want.name, sc.name, 'expected.json is out of date: run test/engine_golden_test.dart with GENERATE_GOLDEN=1');
    const got = run(sc);
    got.steps.forEach((g, i) => {
      assert.deepEqual(g, want.steps[i], `${sc.name} · step ${i} (${g.op})`);
    });
    assert.equal(got.steps.length, want.steps.length);
  });
}
