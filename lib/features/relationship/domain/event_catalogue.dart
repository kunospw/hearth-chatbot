import 'relationship_models.dart';

/// One kind of moment the engine knows about (RELATIONSHIP_ENGINE.md,
/// "Event catalogue"). The model may only *propose* one of these.
class EventKind {
  const EventKind({
    required this.id,
    required this.userLabel,
    required this.category,
    required this.deltas,
    this.cooldown = 6,
    this.contradicts = const {},
    this.needsEarlier,
    this.minTension,
    this.romanceOnly = false,
    this.characterSide = false,
  });

  final String id;

  /// How the timeline names it when the user did it ("You made a promise").
  final String userLabel;
  final TimelineKind category;
  final Map<RelValue, double> deltas;

  /// This kind counts at most once per [cooldown] user turns.
  final int cooldown;

  /// Tags of locked facts this kind would contradict.
  final Set<String> contradicts;

  /// Another kind that must have counted before (promise_kept → promise_made).
  final String? needsEarlier;

  /// Only counts when tension is above this (apology / reconciliation).
  final double? minTension;

  /// Only when the relationship type allows romance.
  final bool romanceOnly;

  /// Usually the character's own action (proposed by the model).
  final bool characterSide;
}

const _t = RelValue.trust;
const _a = RelValue.affection;
const _x = RelValue.attraction;
const _n = RelValue.tension;

/// The server-side catalogue, keyed by kind id.
const Map<String, EventKind> eventCatalogue = {
  'promise_made': EventKind(
    id: 'promise_made',
    userLabel: 'You made a promise',
    category: TimelineKind.shift,
    deltas: {_t: 4},
  ),
  'promise_kept': EventKind(
    id: 'promise_kept',
    userLabel: 'You kept your word',
    category: TimelineKind.milestone,
    deltas: {_t: 6},
    needsEarlier: 'promise_made',
  ),
  'promise_broken': EventKind(
    id: 'promise_broken',
    userLabel: 'You broke a promise',
    category: TimelineKind.setback,
    deltas: {_t: -8, _n: 6},
    contradicts: {'keeps-promises'},
  ),
  'help_offered': EventKind(
    id: 'help_offered',
    userLabel: 'You offered help',
    category: TimelineKind.shift,
    deltas: {_t: 3, _a: 1},
  ),
  'rescue': EventKind(
    id: 'rescue',
    userLabel: 'You came to the rescue',
    category: TimelineKind.milestone,
    deltas: {_t: 6, _a: 3},
  ),
  'boundary_respected': EventKind(
    id: 'boundary_respected',
    userLabel: 'You respected a boundary',
    category: TimelineKind.shift,
    deltas: {_t: 3, _n: -1},
  ),
  'boundary_crossed': EventKind(
    id: 'boundary_crossed',
    userLabel: 'You pushed past a boundary',
    category: TimelineKind.setback,
    deltas: {_t: -3, _n: 5},
  ),
  'vulnerability_shared': EventKind(
    id: 'vulnerability_shared',
    userLabel: 'You opened up',
    category: TimelineKind.shift,
    deltas: {_t: 3, _a: 2},
    characterSide: true,
  ),
  'conflict': EventKind(
    id: 'conflict',
    userLabel: 'You said something cruel',
    category: TimelineKind.setback,
    deltas: {_n: 4},
  ),
  'apology': EventKind(
    id: 'apology',
    userLabel: 'You apologised or told the truth',
    category: TimelineKind.reconcile,
    deltas: {_n: -4, _t: 2},
    minTension: 10,
  ),
  'reconciliation': EventKind(
    id: 'reconciliation',
    userLabel: 'You made things right',
    category: TimelineKind.reconcile,
    deltas: {_n: -4, _t: 2},
    minTension: 10,
  ),
  'betrayal': EventKind(
    id: 'betrayal',
    userLabel: 'A betrayal',
    category: TimelineKind.setback,
    deltas: {_t: -12, _a: -4, _n: 10},
    contradicts: {'loyal'},
    characterSide: true,
  ),
  'appreciation': EventKind(
    id: 'appreciation',
    userLabel: 'You showed appreciation',
    category: TimelineKind.shift,
    deltas: {_a: 1},
    cooldown: 10,
  ),
  'romantic_gesture': EventKind(
    id: 'romantic_gesture',
    userLabel: 'A romantic gesture',
    category: TimelineKind.shift,
    deltas: {_x: 2},
    romanceOnly: true,
    contradicts: {'family', 'platonic-only'},
  ),
};

/// Picks at most one kind from what the user wrote (rule matchers; the server
/// adds a small classifier on top). Order matters: the first match wins.
final List<(String, RegExp)> _rules = [
  (
    'promise_kept',
    RegExp(
      r"\b(i kept (my|the) (promise|word)|as promised|a promise kept)\b",
      caseSensitive: false,
    ),
  ),
  (
    'promise_broken',
    RegExp(
      r"\b(i broke (my|the|our) (promise|word)|i lied to you)\b",
      caseSensitive: false,
    ),
  ),
  (
    'promise_made',
    RegExp(
      r"\b(promise|i swear|you have my word|i won't tell|keep (it|your) secret)\b",
      caseSensitive: false,
    ),
  ),
  (
    'rescue',
    RegExp(
      r"\b(i'll (save|rescue|pull) you|i pulled you out|grab my hand)\b",
      caseSensitive: false,
    ),
  ),
  (
    'help_offered',
    RegExp(
      r"\b(let me help|i'll help|hold the lamp|i'll stay|protect you|i've got you|together)\b",
      caseSensitive: false,
    ),
  ),
  (
    'boundary_respected',
    RegExp(
      r"\b(take your time|no pressure|i won't push|i'll wait|you don't have to (tell|say))\b",
      caseSensitive: false,
    ),
  ),
  (
    'boundary_crossed',
    RegExp(
      r"\b(open it anyway|just tell me|why won't you|read it without|go through your)\b",
      caseSensitive: false,
    ),
  ),
  (
    'apology',
    RegExp(
      r"\b(i'm sorry|i apologi[sz]e|i was wrong|the truth is|forgive me)\b",
      caseSensitive: false,
    ),
  ),
  (
    'appreciation',
    RegExp(
      r"\b(thank you|thanks|that was kind|i'm glad you)\b",
      caseSensitive: false,
    ),
  ),
  (
    'conflict',
    RegExp(r"\b(liar|coward|shut up|pathetic|useless)\b", caseSensitive: false),
  ),
  (
    'romantic_gesture',
    RegExp(
      r"\b(beautiful|kiss|handsome|pretty|hold your hand)\b",
      caseSensitive: false,
    ),
  ),
];

/// The kind this message looks like, or null.
String? classifyUserText(String text) {
  // Phone keyboards type ’ for '; the rules are written with '.
  final t = text.replaceAll(RegExp('[‘’ʼ]'), "'");
  for (final (id, re) in _rules) {
    if (re.hasMatch(t)) return id;
  }
  return null;
}
