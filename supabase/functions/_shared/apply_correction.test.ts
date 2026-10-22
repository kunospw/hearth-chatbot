import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RelationshipEngine } from './engine/engine.ts';
import { handleApplyCorrection, type CorrectionDeps } from './apply_correction.ts';
import { FakeStore, ids, sampleContext } from '../../tests/support/fake_store.ts';

let n = 0;
const uid = () => `00000000-0000-4000-8000-${String(++n).padStart(12, '0')}`;

async function setup() {
  const store = new FakeStore(sampleContext());
  const deps: CorrectionDeps = { store, engine: new RelationshipEngine(uid), now: () => new Date('2026-03-10T09:00:00Z') };
  const rel = await store.ensureRelationship(store.userId, ids.character, ids.persona);
  return { store, deps, rel };
}

async function call(deps: CorrectionDeps, body: unknown, user?: string) {
  const res = await handleApplyCorrection(body, user ?? (deps.store as FakeStore).userId, deps);
  return { status: res.status, json: await res.json() };
}

test('correct: your numbers become the baseline, clamped; the response is the new state', async () => {
  const { deps, rel } = await setup();
  const r = await call(deps, { action: 'correct', relationshipId: rel.id, values: { trust: 120, affection: 40.04, attraction: -5, tension: 10 }, reason: 'We made up' });
  assert.equal(r.status, 200);
  assert.deepEqual(r.json.relationship.values, { trust: 100, affection: 40, attraction: 0, tension: 10 });
  const ev = r.json.relationship.events.find((e: any) => e.kindId === 'correction');
  assert.equal(ev.title, 'We made up');
  assert.equal(ev.source, 'user');
  assert.equal(r.json.relationship.events[0].category, 'milestone'); // the stage moved, so it says so
});

test('correct: bad numbers are refused', async () => {
  const { deps, rel } = await setup();
  for (const v of [{ trust: 'a', affection: 1, attraction: 1, tension: 1 }, { trust: NaN, affection: 1, attraction: 1, tension: 1 }, { trust: 1 }]) {
    assert.equal((await call(deps, { action: 'correct', relationshipId: rel.id, values: v })).status, 400);
  }
});

test('type, pacing, presets and stages', async () => {
  const { deps, rel } = await setup();
  let r = await call(deps, { action: 'set_type', relationshipId: rel.id, type: 'platonic' });
  assert.equal(r.json.relationship.type, 'platonic');
  r = await call(deps, { action: 'set_pacing', relationshipId: rel.id, pacing: 'manual' });
  assert.equal(r.json.relationship.pacing, 'manual');
  r = await call(deps, { action: 'apply_preset', relationshipId: rel.id, presetId: 'family' });
  assert.equal(r.json.relationship.stages[0], 'Estranged');
  r = await call(deps, { action: 'save_stages', relationshipId: rel.id, names: ['', 'Pals'], current: 3, lock: true });
  assert.equal(r.json.relationship.stages[1], 'Pals');
  assert.equal(r.json.relationship.stageIdx, 3);
  assert.equal(r.json.relationship.stageLocked, true);
  assert.equal((await call(deps, { action: 'set_type', relationshipId: rel.id, type: 'bestie' })).status, 400);
  assert.equal((await call(deps, { action: 'set_pacing', relationshipId: rel.id, pacing: 'warp' })).status, 400);
  assert.equal((await call(deps, { action: 'apply_preset', relationshipId: rel.id, presetId: 'zzz' })).status, 400);
  assert.equal((await call(deps, { action: 'save_stages', relationshipId: rel.id, names: [], current: 9, lock: false })).status, 400);
});

test('set_starting_point: starts over as a couple, keeps the history, and is refused for junk', async () => {
  const { store, deps, rel } = await setup();
  await call(deps, { action: 'correct', relationshipId: rel.id, values: { trust: 30, affection: 25, attraction: 0, tension: 10 } });
  await call(deps, { action: 'save_stages', relationshipId: rel.id, names: [], current: 2, lock: true });
  const r = await call(deps, { action: 'set_starting_point', relationshipId: rel.id, startingPoint: 'together' });
  assert.equal(r.status, 200);
  const j = r.json.relationship;
  assert.equal(j.startingPoint, 'together');
  assert.equal(j.type, 'romantic');
  assert.equal(j.pacing, 'balanced');
  assert.deepEqual(j.values, { trust: 70, affection: 75, attraction: 70, tension: 0 });
  assert.equal(j.stages[j.stageIdx], 'Happy Together');
  assert.equal(j.stageLocked, false, 'starting over unlocks the stage');
  const ev = j.events[0];
  assert.equal(ev.title, 'Starting point: Together');
  assert.equal(ev.category, 'correction');
  assert.equal(ev.source, 'user');
  assert.equal(ev.undoable, false);
  assert.deepEqual(ev.deltas, { trust: 40, affection: 50, attraction: 70, tension: -10 });
  assert.ok(j.events.some((e: any) => e.kindId === 'correction'), 'earlier corrections stay in the timeline');
  assert.equal(store.relationships.get(rel.id)!.startingPoint, 'together');

  // the same starting point again, with nothing changed since, logs nothing
  const commits = store.commits;
  const again = await call(deps, { action: 'set_starting_point', relationshipId: rel.id, startingPoint: 'together' });
  assert.equal(again.json.relationship.events.length, j.events.length);
  assert.equal(store.commits, commits);

  for (const bad of ['pen-pals', '', 5, undefined]) {
    assert.equal((await call(deps, { action: 'set_starting_point', relationshipId: rel.id, startingPoint: bad })).status, 400);
  }
});

test('facts: add, lock, remove', async () => {
  const { deps, rel } = await setup();
  let r = await call(deps, { action: 'add_fact', relationshipId: rel.id, text: 'You are siblings.', locked: true });
  const fact = r.json.relationship.facts[0];
  assert.deepEqual(fact.tags, ['family']);
  r = await call(deps, { action: 'set_fact_locked', relationshipId: rel.id, factId: fact.id, locked: false });
  assert.equal(r.json.relationship.facts[0].locked, false);
  r = await call(deps, { action: 'remove_fact', relationshipId: rel.id, factId: fact.id });
  assert.equal(r.json.relationship.facts.length, 0);
  assert.equal((await call(deps, { action: 'add_fact', relationshipId: rel.id, text: '   ' })).status, 400);
  assert.equal((await call(deps, { action: 'add_fact', relationshipId: rel.id, text: 'x'.repeat(301) })).status, 400);
});

test('undo strikes the event through and takes its values back', async () => {
  const { deps, rel } = await setup();
  const c = await call(deps, { action: 'correct', relationshipId: rel.id, values: { trust: 50, affection: 15, attraction: 0, tension: 0 } });
  const eventId = c.json.relationship.events.find((e: any) => e.kindId === 'correction').id;
  const u = await call(deps, { action: 'undo', relationshipId: rel.id, eventId });
  assert.equal(u.json.relationship.values.trust, 20);
  assert.equal(u.json.relationship.events.find((e: any) => e.id === eventId).undoneBy !== null, true);
  // undoing twice, or something that cannot be undone, changes nothing
  const again = await call(deps, { action: 'undo', relationshipId: rel.id, eventId });
  assert.equal(again.json.relationship.events.length, u.json.relationship.events.length);
});

test('manual pacing: edit a message, accept and dismiss suggestions', async () => {
  const { store, deps, rel } = await setup();
  await call(deps, { action: 'set_pacing', relationshipId: rel.id, pacing: 'manual' });
  // the promise in the saved message, evaluated as if it had just been edited
  const r = await call(deps, { action: 'reevaluate_message', relationshipId: rel.id, messageId: ids.user1 });
  assert.equal(r.json.note.text, 'Suggested change · review it');
  assert.equal(r.json.relationship.pending.length, 1);
  const sid = r.json.relationship.pending[0].id;
  const a = await call(deps, { action: 'accept_suggestion', relationshipId: rel.id, suggestionId: sid });
  assert.equal(a.json.relationship.values.trust, 24);
  assert.equal(a.json.relationship.pending.length, 0);
  assert.equal(a.json.relationship.events[0].source, 'approved');
  assert.equal(store.relationships.get(rel.id)!.values.trust, 24);

  // edit it into something else
  store.ctx.messages[1].alts = ['I broke my promise to you and I lied to you.'];
  const e = await call(deps, { action: 'reevaluate_message', relationshipId: rel.id, messageId: ids.user1 });
  assert.equal(e.json.relationship.values.trust, 20 - 0); // the approved promise was taken back; the new text is a suggestion again
  assert.equal(e.json.relationship.pending.length, 1);
  const d = await call(deps, { action: 'dismiss_suggestion', relationshipId: rel.id, suggestionId: e.json.relationship.pending[0].id });
  assert.equal(d.json.relationship.pending.length, 0);
});

test('reevaluate_message only works on your own user messages', async () => {
  const { deps, rel } = await setup();
  assert.equal((await call(deps, { action: 'reevaluate_message', relationshipId: rel.id, messageId: ids.ai1 })).status, 404);
  assert.equal((await call(deps, { action: 'reevaluate_message', relationshipId: rel.id, messageId: uid().replace(/^0/, '7') })).status, 404);
});

test('recount_proposal counts a stored model proposal again, after validating it', async () => {
  const { store, deps, rel } = await setup();
  store.ctx.messages.push({ id: ids.ai2, role: 'ai', alts: ['one', 'She says: "I haven\'t shown that to anyone."'], altIndex: 1 });
  await store.saveProposal(store.userId, {
    messageId: ids.ai2,
    altIndex: 1,
    relationshipId: rel.id,
    kind: 'vulnerability_shared',
    evidence: "I haven't shown that to anyone",
    reason: 'Vesper showed the logbook',
  });
  const r = await call(deps, { action: 'recount_proposal', relationshipId: rel.id, messageId: ids.ai2, altIndex: 1 });
  assert.equal(r.json.note.text, 'Trust grew');
  assert.equal(r.json.relationship.events[0].kindId, 'vulnerability_shared');
  // version 0 of that reply proposed nothing
  const none = await call(deps, { action: 'recount_proposal', relationshipId: rel.id, messageId: ids.ai2, altIndex: 0 });
  assert.equal(none.json.note, null);
  // counting twice does not double it
  const twice = await call(deps, { action: 'recount_proposal', relationshipId: rel.id, messageId: ids.ai2, altIndex: 1 });
  assert.equal(twice.json.relationship.events.filter((e: any) => e.kindId === 'vulnerability_shared').length, 1);
});

test('other people’s relationships, unknown actions and junk are refused', async () => {
  const { deps, rel } = await setup();
  assert.equal((await call(deps, { action: 'set_pacing', relationshipId: rel.id, pacing: 'fast' }, '99999999-9999-4999-8999-999999999999')).status, 404);
  assert.equal((await call(deps, { action: 'explode', relationshipId: rel.id })).status, 400);
  assert.equal((await call(deps, { action: 'set_pacing', relationshipId: 'nope', pacing: 'fast' })).status, 400);
  assert.equal((await call(deps, 'hello')).status, 400);
  assert.equal((await call(deps, { relationshipId: rel.id })).status, 400);
});

test('a version conflict is retried', async () => {
  const { store, deps, rel } = await setup();
  store.conflicts = 2;
  const r = await call(deps, { action: 'set_pacing', relationshipId: rel.id, pacing: 'fast' });
  assert.equal(r.status, 200);
  assert.equal(r.json.relationship.pacing, 'fast');
});
