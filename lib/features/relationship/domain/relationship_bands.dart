import 'relationship_models.dart';

/// Stage arcs you can start from.
class StagePreset {
  const StagePreset(this.id, this.label, this.stages, this.romanticFrom);

  final String id;
  final String label;
  final List<String> stages;
  final int? romanticFrom;
}

const stagePresets = <StagePreset>[
  StagePreset('romance', 'Romance arc', [
    'Strangers',
    'Wary Acquaintances',
    'Reluctant Allies',
    'Growing Trust',
    'Unspoken Feelings',
    'Established Relationship',
  ], 4),
  StagePreset('friendship', 'Friendship', [
    'Strangers',
    'Acquaintances',
    'Allies',
    'Friends',
    'Close Friends',
    'Found Family',
  ], null),
  StagePreset('rivalry', 'Rivalry', [
    'Rivals',
    'Grudging Respect',
    'Uneasy Truce',
    'Reluctant Allies',
    'Trusted Rival',
    'Partners',
  ], null),
  StagePreset('family', 'Family', [
    'Estranged',
    'Distant',
    'Thawing',
    'Reconnecting',
    'Close',
    'Unbreakable',
  ], null),
];

StagePreset presetById(String id) => stagePresets.firstWhere((p) => p.id == id);

/// A plain word for a value ("Cautious", "Fond"). The same table is shown in
/// the journal and sent to the model, so what you read is what it is told.
String wordFor(RelValue k, double v) => switch (k) {
  RelValue.trust =>
    v < 20
        ? 'Wary'
        : v < 40
        ? 'Cautious'
        : v < 60
        ? 'Steady'
        : v < 80
        ? 'Deep'
        : 'Unshakeable',
  RelValue.affection =>
    v < 20
        ? 'Cool'
        : v < 40
        ? 'Polite warmth'
        : v < 60
        ? 'Fond'
        : v < 80
        ? 'Warm'
        : 'Devoted',
  RelValue.attraction =>
    v < 20
        ? 'None shown'
        : v < 40
        ? 'A flicker'
        : v < 60
        ? 'Noticeable'
        : v < 80
        ? 'Strong'
        : 'Undeniable',
  RelValue.tension =>
    v < 15
        ? 'At ease'
        : v < 35
        ? 'Mild'
        : v < 60
        ? 'Strained'
        : 'Volatile',
};

/// The four "how they act right now" lines. Deterministic value bands.
List<String> behaviorLines(Relationship r) {
  final v = r.values;
  final romance = r.type.romanceAllowed;
  return [
    v.trust < 25
        ? 'Keeps answers short and guards anything personal.'
        : v.trust < 50
        ? 'Shares facts and plans, but not feelings. Talks about the past only if asked gently.'
        : v.trust < 75
        ? 'Confides in you and asks your opinion before big decisions.'
        : 'Trusts you with secrets — and with their safety.',
    v.affection < 25
        ? 'Polite, a little cool.'
        : v.affection < 50
        ? 'Shows warmth through small actions more than words.'
        : 'Openly glad to see you; teases you and checks on you.',
    v.tension > 40
        ? 'On edge: likely to argue, test you or pull away.'
        : v.tension > 15
        ? 'Still a little wary after recent friction; avoids sore subjects.'
        : 'At ease in your company.',
    !romance
        ? 'Romance is off the table — affection reads as friendship, family or respect.'
        : v.attraction < 30
        ? 'Shows no romantic interest; fondness stays platonic for now.'
        : v.attraction < 60
        ? 'Small, unspoken signs of attraction — never named aloud.'
        : 'Romantic feelings are present and may be acknowledged.',
  ];
}

/// The block added to the model's prompt every turn (~150–200 tokens), after
/// the character card and before memories. Built on the server; the app only
/// shows it ("See exactly what the AI is told").
String promptBlock(Relationship r) {
  final v = r.values;
  final romance = r.type.romanceAllowed;
  final lines = <String>[
    '[relationship — set by the app, read-only]',
    'stage: ${r.stageName}${r.stageLocked ? ' (locked by user)' : ''}',
    'type: ${r.type.label}${r.type == RelationType.undecided ? ' — do not assume romance' : (romance ? '' : ' — no romance')}',
    'trust ${v.trust.round()} (${wordFor(RelValue.trust, v.trust).toLowerCase()}), '
        'affection ${v.affection.round()} (${wordFor(RelValue.affection, v.affection).toLowerCase()}), '
        'attraction ${romance ? v.attraction.round() : 'n/a'}, '
        'tension ${v.tension.round()} (${wordFor(RelValue.tension, v.tension).toLowerCase()})',
    'pacing: ${r.pacing.label.toLowerCase()} — change openness gradually; no sudden confessions',
    'play it like this:',
    for (final l in behaviorLines(r)) '- $l',
  ];
  final locked = r.facts.where((f) => f.locked).toList();
  if (locked.isNotEmpty) {
    lines.add('never contradict:');
    for (final f in locked) {
      lines.add('- ${f.text}');
    }
  }
  final turning = r.events.where(
    (e) => e.category != TimelineKind.correction && !e.isUndone,
  );
  if (turning.isNotEmpty) {
    lines.add('latest turning point: ${turning.first.title}');
  }
  lines.add(
    'you may propose ONE relationship_event {kind, reason}; the app decides whether it counts.',
  );
  return lines.join('\n');
}

const List<double> stageThresholds = [-1000, 15, 32, 46, 60, 75];

/// 0.6·trust + 0.4·affection − 0.3·tension.
double stageScore(Values v) =>
    v.trust * 0.6 + v.affection * 0.4 - v.tension * 0.3;

/// Is romance (attraction ≥ 35 on a type that allows it) still missing for the
/// romantic stages of this arc?
bool romanceGateClosed(Relationship r) =>
    r.romanticFrom != null &&
    !(r.type.romanceAllowed && r.values.attraction >= 35);

/// The stage these values map to, with hysteresis (a stage only drops once the
/// score is 5 below its threshold), the romance gate, and the stage lock.
int stageFor(Relationship r) {
  if (r.stageLocked) return r.stageIdx;
  final last = r.stages.length - 1;
  final score = stageScore(r.values);
  var idx = 0;
  for (var i = 0; i < stageThresholds.length; i++) {
    if (score >= stageThresholds[i]) idx = i;
  }
  idx = idx.clamp(0, last);
  final cap = (r.romanticFrom != null && romanceGateClosed(r))
      ? r.romanticFrom! - 1
      : last;
  if (idx > cap) idx = cap;
  // Hysteresis: hold the current stage until the score is clearly below it.
  final cur = r.stageIdx.clamp(0, last);
  if (idx < cur && cur <= cap && score >= stageThresholds[cur] - 5) idx = cur;
  return idx.clamp(0, last);
}

/// "Next: …" under the stage in the journal.
String nextHint(Relationship r) {
  final last = r.stages.length - 1;
  if (r.stageLocked) {
    return 'This stage is locked, so it won’t change on its own. Unlock it in Edit stages.';
  }
  if (r.stageIdx >= last) {
    return 'The last stage on this arc — though it can still slip if things go wrong.';
  }
  final score = stageScore(r.values);
  final next = r.stageIdx + 1;
  if (r.romanticFrom != null &&
      next >= r.romanticFrom! &&
      score >= stageThresholds[next]) {
    return 'Next: ${r.stages[next]} — only if attraction grows in the story. '
        'Affection alone won’t get there.';
  }
  final gap = stageThresholds[next] - score;
  return 'Next: ${r.stages[next]}${gap > 12 ? ' — still a long way off. ' : ' — getting closer. '}'
      '${r.values.tension > 20 ? 'Easing the tension would help most.' : 'More trust would help most.'}';
}

/// What the journal says about the "Kind of relationship" setting.
String typeHint(RelationType t) => !t.romanceAllowed
    ? 'Romance is off. Affection is played as friendship, family or respect.'
    : t == RelationType.undecided
    ? 'High affection never means romance on its own. Romance only develops if attraction grows in the story.'
    : 'Romance is allowed. It still has to grow through the story.';

/// "+4" / "−3" with a real minus sign.
String signed(double v) {
  final a = v.abs();
  final n = a == a.roundToDouble()
      ? a.toStringAsFixed(0)
      : a.toStringAsFixed(1);
  return '${v > 0 ? '+' : '−'}$n';
}

/// A day label for timeline rows: Today, Yesterday, a weekday, or "Oct 9".
String dayLabel(DateTime at, DateTime now) {
  final d = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(d).inDays;
  if (now.difference(at).inMinutes < 1) return 'Just now';
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return days < 7 ? wd[at.weekday - 1] : '${mo[at.month - 1]} ${at.day}';
}

/// How openly a character replies, from the relationship: guarded, opening or
/// warm. High tension keeps them guarded; later stages open up.
String replyTier(Relationship r) {
  if (r.values.tension > 45) return 'guarded';
  if (r.stageIdx >= 4) return 'warm';
  if (r.stageIdx >= 2) return 'opening';
  return 'guarded';
}
