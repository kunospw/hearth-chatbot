import { test } from 'node:test';
import assert from 'node:assert/strict';
import { StreamFilter, buildMessages, buildSystemPrompt, contentPolicy, parseModelReply, DEFAULT_SETTINGS } from './prompt.ts';
import { sampleContext } from '../../tests/support/fake_store.ts';
import { newRelationship } from '../../tests/support/fake_store.ts';

const tag = (j: unknown) => `<relationship_event>${JSON.stringify(j)}</relationship_event>`;

test('parseModelReply: strips the tag and reads one proposal', () => {
  const r = parseModelReply(`She nods. ${tag({ kind: 'rescue', evidence: 'pulled you out', reason: 'saved me' })}`);
  assert.equal(r.text, 'She nods.');
  assert.deepEqual(r.proposal, { kind: 'rescue', evidence: 'pulled you out', reason: 'saved me' });
  assert.equal(r.discarded, 0);
});

test('parseModelReply: the documented contract shape works too', () => {
  const r = parseModelReply(tag({ relationship_event: { kind: 'vulnerability_shared', actor: 'character', evidence: 'q', reason: 'r' } }));
  assert.equal(r.proposal?.kind, 'vulnerability_shared');
});

test('parseModelReply: numbers and extra fields are ignored, a second event is discarded', () => {
  const r = parseModelReply(
    `Hi. ${tag({ kind: 'rescue', evidence: 'a', reason: 'b', trust: 99, deltas: { trust: 50 } })}${tag({ kind: 'betrayal', evidence: 'c' })}`,
  );
  assert.deepEqual(r.proposal, { kind: 'rescue', evidence: 'a', reason: 'b' });
  assert.equal(r.discarded, 1);
  assert.equal(r.text, 'Hi.');
});

test('parseModelReply: broken or incomplete tags are dropped, never shown', () => {
  assert.equal(parseModelReply('Hello <relationship_event>{not json}</relationship_event>').text, 'Hello');
  assert.equal(parseModelReply('Hello <relationship_event>{"kind":"res').text, 'Hello');
  assert.equal(parseModelReply('Hello <relationship_event>{"kind":"res').proposal, null);
  assert.equal(parseModelReply(`Hello ${tag({ kind: 5 })}`).proposal, null);
});

test('StreamFilter: ordinary text passes straight through', () => {
  const f = new StreamFilter();
  assert.equal(f.push('Hello '), 'Hello ');
  assert.equal(f.push('there <b>'), 'there <b>');
  assert.equal(f.flush(), '');
});

test('StreamFilter: holds back a possible tag start and releases it when it is not one', () => {
  const f = new StreamFilter();
  let shown = f.push('a < b and <rel');
  assert.equal(shown, 'a < b and ');
  shown += f.push('ax, ok');
  shown += f.flush();
  assert.equal(shown, 'a < b and <relax, ok');
});

test('StreamFilter: the tag never reaches the screen, however it is split', () => {
  const text = `The door opens. ${tag({ kind: 'rescue', evidence: 'x', reason: 'y' })}`;
  for (let size = 1; size <= 9; size++) {
    const f = new StreamFilter();
    let shown = '';
    for (let i = 0; i < text.length; i += size) shown += f.push(text.slice(i, i + size));
    shown += f.flush();
    assert.equal(shown, 'The door opens. ', `chunk size ${size}`);
    assert.equal(parseModelReply(f.full).proposal?.kind, 'rescue');
  }
});

test('content policy: the minors rule is always there; mature content only when switched on', () => {
  const off = contentPolicy(false);
  const on = contentPolicy(true);
  for (const p of [off, on]) {
    assert.match(p, /adult \(18 or older\)/);
    assert.match(p, /under 18/);
    assert.match(p, /never unlocks anything/);
  }
  assert.match(off, /non-explicit/);
  assert.doesNotMatch(off, /turned on mature content/);
  assert.match(on, /turned on mature content/);
  assert.doesNotMatch(on, /non-explicit/);
});

test('system prompt: card, persona, world, memories, relationship block, rules', () => {
  const ctx = sampleContext();
  const rel = newRelationship('r', ctx.character.id, ctx.persona.id);
  const s = buildSystemPrompt({
    character: ctx.character,
    personaName: 'Wren',
    personaDescription: 'A courier.',
    universe: ctx.universe,
    memories: ctx.memories,
    relationship: rel,
    mode: 'chat',
    settings: DEFAULT_SETTINGS,
    adultContent: false,
  });
  assert.match(s, /You are Vesper Hale/);
  assert.match(s, /The user plays Wren\. A courier\./);
  assert.match(s, /Personality: Dry, guarded, observant\./);
  assert.match(s, /World: The Saltmarsh Coast/);
  assert.ok(s.indexOf('Her father died at sea.') < s.indexOf('The bell is cracked.'), 'pinned memories first');
  assert.match(s, /\[relationship — set by the app, read-only\]/);
  assert.match(s, /stage: Acquaintances/);
  assert.match(s, /<relationship_event>/);
  assert.match(s, /one of: promise_made, /);
  assert.match(s, /Never write Wren's words/);
});

test('system prompt: story mode narrates; a rewrite is told to avoid the earlier text', () => {
  const ctx = sampleContext();
  const s = buildSystemPrompt({
    character: ctx.character,
    personaName: 'Wren',
    personaDescription: '',
    universe: null,
    memories: [],
    relationship: newRelationship('r', 'c', 'p'),
    mode: 'story',
    settings: { ...DEFAULT_SETTINGS, length: 'long', style: 'literary' },
    adultContent: false,
    avoidText: 'She laughed softly.',
  });
  assert.match(s, /narrator of an interactive story/);
  assert.match(s, /up to about 450 words/);
  assert.match(s, /Rich, rhythmic prose/);
  assert.match(s, /She laughed softly\./);
});

test('messages: the last N, roles mapped, and a closing user turn when the character spoke last', () => {
  const hist = [
    { id: '1', role: 'ai' as const, text: 'hello' },
    { id: '2', role: 'user' as const, text: 'hi' },
    { id: '3', role: 'ai' as const, text: 'how are you' },
  ];
  const m = buildMessages('SYS', hist, 40);
  assert.deepEqual(m.map((x) => x.role), ['system', 'assistant', 'user', 'assistant', 'user']);
  assert.equal(m[m.length - 1].content, '(Continue.)');
  const short = buildMessages('SYS', hist, 2);
  assert.equal(short.length, 1 + 2 + 1);
  assert.deepEqual(buildMessages('SYS', [], 40).map((x) => x.role), ['system', 'user']);
});
