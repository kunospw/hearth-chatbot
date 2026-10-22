import 'event_catalogue.dart';
import 'relationship_bands.dart';
import 'relationship_models.dart';

// The deterministic relationship engine (RELATIONSHIP_ENGINE.md, "Engine loop").
//
// This is PURE DART with no Flutter imports. It exists for the mock phase and
// for tests. In production the same rules run in the `chat_turn` edge function
// and the app only displays the result: the Flutter app must never compute or
// write relationship values itself (phase 6 swaps the mock backend for the
// server one).

/// Why a message or proposal did not change anything.
enum IgnoreReason {
  noMatch,
  trivial,
  duplicate,
  unknownKind,
  noEvidence,
  cooldown,
  earlierMissing,
  tensionTooLow,
  romanceOff,
  contradictsFact,
  sceneBudget,
  tooSmall,
}

/// A user message to evaluate.
class UserTurn {
  const UserTurn({
    required this.messageId,
    required this.text,
    required this.now,
    this.conversationId,
    this.chatTitle = 'Story',
  });

  final String messageId;
  final String text;
  final DateTime now;
  final String? conversationId;
  final String chatTitle;
}

/// What the model proposed in its reply: one event, with evidence. Numbers are
/// never accepted from the model.
class ModelProposal {
  const ModelProposal({
    required this.kindId,
    required this.evidence,
    required this.reason,
    required this.messageId,
    required this.recentMessages,
    required this.now,
    this.conversationId,
    this.chatTitle = 'Story',
  });

  final String kindId;

  /// A quote from the last messages that backs the proposal up.
  final String evidence;
  final String reason;
  final String messageId;

  /// The last messages (newest last); the evidence must appear in the last 6.
  final List<String> recentMessages;
  final DateTime now;
  final String? conversationId;
  final String chatTitle;
}

sealed class EngineOutcome {
  const EngineOutcome(this.relationship);
  final Relationship relationship;
}

/// A change was applied (and maybe moved the stage).
class Applied extends EngineOutcome {
  const Applied(super.relationship, this.event, this.note, {this.stageEvent});
  final RelationshipEvent event;
  final RelationshipEvent? stageEvent;
  final RelationshipNote note;
}

/// Manual pacing: a suggestion now waits for approval.
class Suggested extends EngineOutcome {
  const Suggested(super.relationship, this.suggestion, this.note);
  final Suggestion suggestion;
  final RelationshipNote note;
}

/// Nothing changed. [counted] means a real moment was rejected (it adds to the
/// "small moments were not counted" note in the journal).
class Ignored extends EngineOutcome {
  const Ignored(super.relationship, this.reason, {this.counted = false});
  final IgnoreReason reason;
  final bool counted;
}

/// The engine. Every method takes a relationship and returns a new one.
class RelationshipEngine {
  const RelationshipEngine();

  static const double sceneBudget = 8;
  static const int sceneWindow = 10;
  static const double dailyCap = 12;
  static const int repeatWindow = 30;
  static const int hashWindow = 20;
  static const int evidenceWindow = 6;
  static const int minWords = 4;

  // ── a user message ────────────────────────────────────────────────────

  /// Classify → validate → apply. [reevaluation] re-runs a message that was
  /// edited: it keeps its turn number instead of counting a new one.
  EngineOutcome processUserMessage(
    Relationship r,
    UserTurn t, {
    bool reevaluation = false,
    int? turn,
  }) {
    // Idempotence: one message counts once.
    final already =
        r.events.any(
          (e) =>
              e.messageId == t.messageId &&
              !e.isUndone &&
              e.source != EventSource.modelProposal &&
              e.undoOf == null,
        ) ||
        r.pending.any((p) => p.messageId == t.messageId);
    if (already) return Ignored(r, IgnoreReason.duplicate);

    final thisTurn = turn ?? (r.turn + 1);
    final norm = normalise(t.text);
    final ooc = RegExp(r'^\s*\(\(.*\)\)\s*$', dotAll: true).hasMatch(t.text);
    final repeated =
        !reevaluation &&
        r.recentHashes.any((h) {
          final i = h.indexOf('|');
          final ht = int.tryParse(h.substring(0, i)) ?? 0;
          return h.substring(i + 1) == norm && thisTurn - ht <= hashWindow;
        });
    final hashes = ooc || reevaluation
        ? r.recentHashes
        : [
            ...r.recentHashes.where((h) {
              final ht = int.tryParse(h.substring(0, h.indexOf('|'))) ?? 0;
              return thisTurn - ht <= hashWindow;
            }),
            '$thisTurn|$norm',
          ];
    final base = r.copyWith(
      turn: reevaluation ? r.turn : thisTurn,
      recentHashes: hashes,
    );

    final kindId = classifyUserText(t.text);
    if (kindId == null) return Ignored(base, IgnoreReason.noMatch);

    final words = t.text.trim().split(RegExp(r'\s+')).length;
    final emojiOnly = !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t.text);
    if (words < minWords || ooc || emojiOnly || repeated) {
      return Ignored(_countIgnored(base), IgnoreReason.trivial, counted: true);
    }

    final label = eventCatalogue[kindId]!.userLabel.toLowerCase();
    final excerpt = t.text.length > 70 ? '${t.text.substring(0, 70)}…' : t.text;
    return _evaluate(
      base,
      kindId,
      thisTurn,
      title: eventCatalogue[kindId]!.userLabel,
      source: EventSource.engine,
      lead: 'Matched “$label” in your message: “$excerpt”.',
      now: t.now,
      messageId: t.messageId,
      conversationId: t.conversationId,
      chatTitle: t.chatTitle,
    );
  }

  /// A message was edited: reverse what the old text caused, then evaluate the
  /// new text as the same turn.
  EngineOutcome reevaluateEdited(Relationship r, UserTurn t) {
    var rel = r;
    int? turn;
    for (final e in r.events.where(
      (e) =>
          e.messageId == t.messageId &&
          !e.isUndone &&
          e.source != EventSource.modelProposal &&
          e.undoOf == null,
    )) {
      turn = e.turn;
      if (e.canUndo) {
        rel = undo(
          rel,
          e.id,
          now: t.now,
          reason: 'You edited the message that caused this.',
        );
      }
    }
    final stale = rel.pending.where((p) => p.messageId == t.messageId).toList();
    if (stale.isNotEmpty) {
      turn ??= stale.first.turn;
      rel = rel.copyWith(
        pending: rel.pending.where((p) => p.messageId != t.messageId).toList(),
        ledger: rel.ledger
            .where(
              (l) =>
                  l.suggestionId == null ||
                  !stale.any((s) => s.id == l.suggestionId),
            )
            .toList(),
      );
    }
    return processUserMessage(
      rel,
      t,
      reevaluation: true,
      turn: turn ?? rel.turn,
    );
  }

  // ── a proposal from the model ─────────────────────────────────────────

  /// The model's own action, validated like anything else. The kind must be in
  /// the catalogue and the evidence must quote one of the last 6 messages.
  EngineOutcome processModelProposal(
    Relationship r,
    ModelProposal p, {
    required String characterFirst,
  }) {
    if (r.events.any(
          (e) =>
              e.messageId == p.messageId && e.kindId == p.kindId && !e.isUndone,
        ) ||
        r.pending.any(
          (s) => s.messageId == p.messageId && s.kindId == p.kindId,
        )) {
      return Ignored(r, IgnoreReason.duplicate);
    }
    if (!eventCatalogue.containsKey(p.kindId)) {
      return Ignored(_countIgnored(r), IgnoreReason.unknownKind, counted: true);
    }
    final window = p.recentMessages.length <= evidenceWindow
        ? p.recentMessages
        : p.recentMessages.sublist(p.recentMessages.length - evidenceWindow);
    final haystack = normalise(window.join(' '));
    final needle = normalise(p.evidence);
    if (needle.isEmpty || !haystack.contains(needle)) {
      return Ignored(_countIgnored(r), IgnoreReason.noEvidence, counted: true);
    }
    final reason = p.reason.trim().isEmpty
        ? eventCatalogue[p.kindId]!.userLabel
        : p.reason.trim();
    return _evaluate(
      r,
      p.kindId,
      r.turn,
      title: reason,
      source: EventSource.modelProposal,
      lead:
          '$characterFirst did something that counts: $reason. They said: “${p.evidence}”.',
      evidence: p.evidence,
      now: p.now,
      messageId: p.messageId,
      conversationId: p.conversationId,
      chatTitle: p.chatTitle,
    );
  }

  // ── validation and application ────────────────────────────────────────

  EngineOutcome _evaluate(
    Relationship r,
    String kindId,
    int turn, {
    required String title,
    required EventSource source,
    required String lead,
    required DateTime now,
    required String messageId,
    String? evidence,
    String? conversationId,
    required String chatTitle,
  }) {
    final kind = eventCatalogue[kindId]!;
    Ignored no(IgnoreReason why) =>
        Ignored(_countIgnored(r), why, counted: true);

    // Romance gate: attraction only counts when the type allows it.
    if (kind.romanceOnly && !r.type.romanceAllowed) {
      return no(IgnoreReason.romanceOff);
    }
    if (kind.minTension != null && r.values.tension <= kind.minTension!) {
      return no(IgnoreReason.tensionTooLow);
    }
    if (kind.needsEarlier != null &&
        !r.events.any((e) => e.kindId == kind.needsEarlier && !e.isUndone)) {
      return no(IgnoreReason.earlierMissing);
    }
    // Locks: an event that contradicts a locked fact (by tag) is rejected.
    for (final f in r.facts.where((f) => f.locked)) {
      if (f.tags.any(kind.contradicts.contains)) {
        return no(IgnoreReason.contradictsFact);
      }
    }

    // Cooldown: each kind counts at most once per `cooldown` user turns.
    final counted = r.ledger.where((l) => l.kindId == kindId).toList();
    if (counted.isNotEmpty &&
        turn - counted.map((l) => l.turn).reduce((a, b) => a > b ? a : b) <
            kind.cooldown) {
      return no(IgnoreReason.cooldown);
    }

    // Diminishing returns: × 1/(1 + 0.5·n), n = times it counted in the last 30 turns.
    final n = counted.where((l) => turn - l.turn < repeatWindow).length;
    final repeat = 1 / (1 + 0.5 * n);
    var deltas = <RelValue, double>{
      for (final e in kind.deltas.entries) e.key: e.value * repeat,
    };
    final multipliers = <String, double>{if (repeat != 1) 'repeat': repeat};

    // Scene budget: at most 8 points in total per 10 turns.
    final used = r.ledger
        .where((l) => turn - l.turn < sceneWindow)
        .fold<double>(0, (s, l) => s + l.magnitude);
    final room = (sceneBudget - used).clamp(0, sceneBudget).toDouble();
    final mag = deltas.values.fold<double>(0, (s, d) => s + d.abs());
    var capped = false;
    if (room <= 0) return no(IgnoreReason.sceneBudget);
    if (mag > room) {
      final f = room / mag;
      deltas = {for (final e in deltas.entries) e.key: e.value * f};
      multipliers['budget'] = f;
      capped = true;
    }

    // Daily cap: ±12 per value per day.
    var dailyHit = false;
    final today = DateTime(now.year, now.month, now.day);
    final todays = r.ledger.where(
      (l) => DateTime(l.at.year, l.at.month, l.at.day) == today,
    );
    deltas = {
      for (final e in deltas.entries)
        e.key: () {
          final pos = todays.fold<double>(
            0,
            (s, l) => s + (l.deltas[e.key] ?? 0).clamp(0, double.infinity),
          );
          final neg = todays.fold<double>(
            0,
            (s, l) =>
                s + (l.deltas[e.key] ?? 0).clamp(double.negativeInfinity, 0),
          );
          final d = e.value;
          final out = d > 0
              ? d.clamp(0, (dailyCap - pos).clamp(0, dailyCap)).toDouble()
              : d.clamp(-dailyCap - neg, 0).toDouble();
          if (out != d) dailyHit = true;
          return out;
        }(),
    };
    if (dailyHit) multipliers['daily'] = 0;

    // Pacing last: gains × up, setbacks × down; then round to 0.5. Manual
    // pacing changes nothing by itself.
    final raw = {for (final e in kind.deltas.entries) e.key: e.value};
    deltas = {
      for (final e in deltas.entries)
        e.key: _round(
          e.value * (_isGain(e.key, e.value) ? r.pacing.up : r.pacing.down),
        ),
    }..removeWhere((_, v) => v == 0);
    if (r.pacing.up != 1 || r.pacing.down != 1) {
      final lead = kind.deltas.entries.first;
      multipliers['pacing'] = _isGain(lead.key, lead.value)
          ? r.pacing.up
          : r.pacing.down;
    }
    if (deltas.isEmpty) return no(IgnoreReason.tooSmall);

    final why = StringBuffer(lead)
      ..write(' ${r.pacing.label} pacing: ')
      ..write(
        raw.entries
            .map(
              (e) =>
                  '${e.key.label} ${signed(e.value)} → ${deltas[e.key] == null ? '0' : signed(deltas[e.key]!)}',
            )
            .join(', '),
      )
      ..write('.')
      ..write(
        n > 0
            ? ' A similar moment already counted, so this one weighs less.'
            : '',
      )
      ..write(
        capped ? ' Capped: this scene has already moved things a lot.' : '',
      )
      ..write(dailyHit ? ' Capped: this value has moved a lot today.' : '');

    final id = _id(r, 'e');
    final note = noteFor(
      deltas,
      kind.category,
      kindId: kindId,
      evidence: evidence,
      reason: source == EventSource.modelProposal ? title : null,
      entryId: id,
    );

    // Manual pacing: suggest instead of change.
    if (r.pacing == RelPacing.manual) {
      final sid = _id(r, 'p');
      final s = Suggestion(
        id: sid,
        kindId: kindId,
        category: kind.category,
        title: title,
        deltas: deltas,
        why: why.toString(),
        at: now,
        turn: turn,
        chatTitle: chatTitle,
        conversationId: conversationId,
        messageId: messageId,
        evidence: evidence,
        multipliers: multipliers,
        source: source,
      );
      final next = r.copyWith(
        pending: [s, ...r.pending],
        ledger: [
          ...r.ledger,
          LedgerEntry(
            kindId: kindId,
            turn: turn,
            at: now,
            deltas: deltas,
            suggestionId: sid,
          ),
        ],
      );
      return Suggested(
        next,
        s,
        const RelationshipNote(
          text: 'Suggested change · review it',
          story: 'The story suggests a shift.',
        ),
      );
    }

    final values = r.values.plus(deltas);
    final event = RelationshipEvent(
      id: id,
      kindId: kindId,
      category: kind.category,
      title: title,
      at: now,
      why: why.toString(),
      source: source,
      deltas: deltas,
      multipliers: multipliers,
      evidence: evidence,
      chatTitle: chatTitle,
      conversationId: conversationId,
      messageId: messageId,
      turn: turn,
      stageBefore: r.stageIdx,
      undoable: true,
    );
    var next = r.copyWith(
      values: values,
      events: [event, ...r.events],
      ledger: [
        ...r.ledger,
        LedgerEntry(
          kindId: kindId,
          turn: turn,
          at: now,
          deltas: deltas,
          eventId: id,
        ),
      ],
    );
    RelationshipEvent? stageEvent;
    final idx = stageFor(next);
    if (idx != next.stageIdx) {
      next = next.copyWith(stageIdx: idx);
      stageEvent = _stageEntry(
        next,
        r.stageIdx,
        EventSource.engine,
        now,
        chatTitle,
        conversationId,
      );
      next = next.copyWith(events: [stageEvent, ...next.events]);
    }
    return Applied(next, event, note, stageEvent: stageEvent);
  }

  // ── suggestions, undo, corrections ────────────────────────────────────

  Relationship acceptSuggestion(
    Relationship r,
    String id, {
    required DateTime now,
  }) {
    final s = r.pending.where((p) => p.id == id).firstOrNull;
    if (s == null) return r;
    final eid = _id(r, 'e');
    final event = RelationshipEvent(
      id: eid,
      kindId: s.kindId,
      category: s.category,
      title: s.title,
      at: now,
      why: '${s.why} Approved by you (Manual pacing).',
      source: EventSource.approved,
      deltas: s.deltas,
      multipliers: s.multipliers,
      evidence: s.evidence,
      chatTitle: s.chatTitle,
      conversationId: s.conversationId,
      messageId: s.messageId,
      turn: s.turn,
      stageBefore: r.stageIdx,
      undoable: true,
    );
    var next = r.copyWith(
      values: r.values.plus(s.deltas),
      pending: r.pending.where((p) => p.id != id).toList(),
      events: [event, ...r.events],
      ledger: [
        for (final l in r.ledger)
          if (l.suggestionId == id)
            LedgerEntry(
              kindId: l.kindId,
              turn: l.turn,
              at: l.at,
              deltas: l.deltas,
              eventId: eid,
            )
          else
            l,
      ],
    );
    final idx = stageFor(next);
    if (idx != next.stageIdx) {
      final before = next.stageIdx;
      next = next.copyWith(stageIdx: idx);
      next = next.copyWith(
        events: [
          _stageEntry(
            next,
            before,
            EventSource.engine,
            now,
            s.chatTitle,
            s.conversationId,
          ),
          ...next.events,
        ],
      );
    }
    return next;
  }

  /// Declining a suggestion means it didn't happen: like an undo, it frees the
  /// kind's cooldown and the budget it would have used.
  Relationship dismissSuggestion(Relationship r, String id) => r.copyWith(
    pending: r.pending.where((p) => p.id != id).toList(),
    ledger: r.ledger.where((l) => l.suggestionId != id).toList(),
    ignored: r.ignored + 1,
  );

  /// Reverses one event: a reversing event is added and the original is struck
  /// through (never deleted). Its cooldown and budget are freed again.
  Relationship undo(
    Relationship r,
    String eventId, {
    required DateTime now,
    String? reason,
  }) {
    final e = r.events.where((x) => x.id == eventId).firstOrNull;
    if (e == null || !e.canUndo) return r;
    final back = {for (final d in e.deltas.entries) d.key: -d.value};
    final rid = _id(r, 'e');
    final reversing = RelationshipEvent(
      id: rid,
      kindId: 'undo',
      category: TimelineKind.correction,
      title: 'Undid: ${e.title}',
      at: now,
      why: reason ?? 'You reversed this change. The values went back; the moment itself still happened in the story.',
      source: EventSource.undo,
      deltas: back,
      chatTitle: 'Relationship journal',
      turn: r.turn,
      undoOf: e.id,
    );
    var next = r.copyWith(
      values: r.values.plus(back),
      events: [
        reversing,
        for (final x in r.events) x.id == e.id ? x.copyWith(undoneBy: rid) : x,
      ],
      ledger: r.ledger.where((l) => l.eventId != e.id).toList(),
    );
    final idx = stageFor(next);
    if (idx != next.stageIdx) {
      final before = next.stageIdx;
      next = next.copyWith(stageIdx: idx);
      next = next.copyWith(
        events: [
          _stageEntry(
            next,
            before,
            EventSource.undo,
            now,
            'Relationship journal',
            null,
          ),
          ...next.events,
        ],
      );
    }
    return next;
  }

  /// Your correction: the new values become the baseline.
  Relationship applyCorrection(
    Relationship r,
    Values target, {
    String? reason,
    required DateTime now,
  }) {
    final deltas = <RelValue, double>{};
    var values = r.values;
    for (final k in RelValue.values) {
      final t = target[k].clamp(0, 100).toDouble();
      final d = _round(t - r.values[k]);
      if (d != 0) deltas[k] = d;
      values = values.withValue(k, t);
    }
    if (deltas.isEmpty) return r;
    final event = RelationshipEvent(
      id: _id(r, 'e'),
      kindId: 'correction',
      category: TimelineKind.correction,
      title: (reason?.trim().isEmpty ?? true)
          ? 'Adjusted by you'
          : reason!.trim(),
      at: now,
      why: 'Manual correction. These values are the new baseline, and the next reply is written with them.',
      source: EventSource.user,
      deltas: deltas,
      chatTitle: 'Relationship journal',
      turn: r.turn,
      stageBefore: r.stageIdx,
      undoable: true,
    );
    var next = r.copyWith(values: values, events: [event, ...r.events]);
    final idx = stageFor(next);
    if (idx != next.stageIdx) {
      final before = next.stageIdx;
      next = next.copyWith(stageIdx: idx);
      next = next.copyWith(
        events: [
          _stageEntry(
            next,
            before,
            EventSource.user,
            now,
            'Relationship journal',
            null,
            via: 'You (via correction)',
          ),
          ...next.events,
        ],
      );
    }
    return next;
  }

  // ── settings ──────────────────────────────────────────────────────────

  /// Switching to Platonic, Family etc. caps the romantic stages; history is kept.
  Relationship setType(Relationship r, RelationType type) {
    final next = r.copyWith(type: type);
    return next.copyWith(stageIdx: stageFor(next));
  }

  Relationship setPacing(Relationship r, RelPacing pacing) =>
      r.copyWith(pacing: pacing);

  Relationship applyPreset(Relationship r, StagePreset p) {
    final next = r.copyWith(
      stages: List.of(p.stages),
      romanticFrom: p.romanticFrom,
      clearRomanticFrom: p.romanticFrom == null,
    );
    return next.copyWith(stageIdx: stageFor(next));
  }

  /// Starts over from [start] (picked in the journal, or by editing the
  /// character): the kind, the stage arc and stage, the pacing and the values
  /// all match it, and the stage is unlocked. Earlier moments stay in the
  /// timeline. It is logged as your correction without an Undo of its own,
  /// because it changes more than the values: pick another starting point.
  Relationship applyStartingPoint(
    Relationship r,
    StartingPoint start, {
    required DateTime now,
  }) {
    final s = startingSetups[start]!;
    final p = presetById(s.presetId);
    final deltas = <RelValue, double>{};
    for (final k in RelValue.values) {
      final d = _round(s.values[k] - r.values[k]);
      if (d != 0) deltas[k] = d;
    }
    final unchanged =
        r.startingPoint == start &&
        r.values == s.values &&
        r.type == s.type &&
        r.pacing == s.pacing &&
        r.stageIdx == s.stageIdx &&
        !r.stageLocked &&
        r.romanticFrom == p.romanticFrom &&
        r.stages.join('\n') == p.stages.join('\n');
    if (unchanged) return r;
    final event = RelationshipEvent(
      id: _id(r, 'e'),
      kindId: 'start',
      category: TimelineKind.correction,
      title: 'Starting point: ${start.label}',
      at: now,
      why:
          'You chose where your story starts. The kind of relationship, the stages, '
          'the pacing and the values now match it, and the next reply is written with them. '
          'Earlier moments stay in the timeline; to change it again, pick another starting point.',
      source: EventSource.user,
      deltas: deltas,
      chatTitle: 'Relationship journal',
      turn: r.turn,
    );
    return r.copyWith(
      startingPoint: start,
      type: s.type,
      pacing: s.pacing,
      values: s.values,
      stages: List.of(p.stages),
      romanticFrom: p.romanticFrom,
      clearRomanticFrom: p.romanticFrom == null,
      stageIdx: s.stageIdx,
      stageLocked: false,
      events: [event, ...r.events],
    );
  }

  /// Edit stage names, set the current stage yourself, and lock it.
  Relationship saveStages(
    Relationship r,
    List<String> names,
    int current,
    bool lock, {
    required DateTime now,
  }) {
    final cleaned = [
      for (var i = 0; i < r.stages.length; i++)
        (i < names.length && names[i].trim().isNotEmpty)
            ? names[i].trim()
            : r.stages[i],
    ];
    var next = r.copyWith(
      stages: cleaned,
      stageIdx: current.clamp(0, cleaned.length - 1),
      stageLocked: lock,
    );
    if (current != r.stageIdx) {
      next = next.copyWith(
        events: [
          RelationshipEvent(
            id: _id(r, 'e'),
            category: TimelineKind.correction,
            title: 'Stage set to ${cleaned[next.stageIdx]}',
            at: now,
            why:
                'You set the stage yourself.${lock ? ' It’s locked, so the engine won’t move it.' : ' The engine may move it again as the story continues.'}',
            source: EventSource.user,
            chatTitle: 'Relationship journal',
            turn: r.turn,
          ),
          ...next.events,
        ],
      );
    }
    return next;
  }

  Relationship addFact(
    Relationship r,
    String text, {
    bool locked = true,
    List<String>? tags,
  }) {
    final t = text.trim();
    if (t.isEmpty) return r;
    final f = Fact(
      id: _id(r, 'f'),
      text: t,
      locked: locked,
      tags: tags ?? inferFactTags(t),
    );
    return r.copyWith(facts: [...r.facts, f]);
  }

  Relationship setFactLocked(Relationship r, String id, bool locked) =>
      r.copyWith(
        facts: [
          for (final f in r.facts) f.id == id ? f.copyWith(locked: locked) : f,
        ],
      );

  Relationship removeFact(Relationship r, String id) =>
      r.copyWith(facts: r.facts.where((f) => f.id != id).toList());

  /// Marks every event from a deleted conversation (they stay in the timeline).
  Relationship markChatDeleted(Relationship r, String conversationId) =>
      r.copyWith(
        events: [
          for (final e in r.events)
            e.conversationId == conversationId
                ? e.copyWith(fromDeletedChat: true)
                : e,
        ],
      );

  // ── helpers ───────────────────────────────────────────────────────────

  Relationship _countIgnored(Relationship r) =>
      r.copyWith(ignored: r.ignored + 1);

  /// A stage milestone entry. [before] is the old stage index.
  RelationshipEvent _stageEntry(
    Relationship r,
    int before,
    EventSource source,
    DateTime now,
    String chat,
    String? conversationId, {
    String? via,
  }) {
    return RelationshipEvent(
      id: _id(r, 'e', salt: 1),
      category: TimelineKind.milestone,
      title: 'Stage: ${r.stageName}',
      at: now,
      why:
          'Trust and affection, minus tension, crossed this stage’s threshold. '
          'Stages only drop after a clear fall, so one bad moment won’t undo a stage.',
      source: source,
      chatTitle: chat,
      conversationId: conversationId,
      turn: r.turn,
      stageBefore: before,
      stageAfter: r.stageIdx,
    );
  }

  String _id(Relationship r, String prefix, {int salt = 0}) =>
      '$prefix${r.turn}_${r.events.length + r.pending.length + r.ledger.length + r.version + salt}';

  static double _round(double v) => (v * 2).round() / 2;

  /// Is this change good for the relationship? More trust is; more tension is
  /// a setback, and less tension is a gain (repairs).
  static bool _isGain(RelValue k, double delta) =>
      k == RelValue.tension ? delta < 0 : delta > 0;

  static RelValue? _mainDelta(Map<RelValue, double> d) {
    if (d.isEmpty) return null;
    return d.entries
        .reduce((a, b) => a.value.abs() >= b.value.abs() ? a : b)
        .key;
  }

  /// The muted line under a message: never numbers.
  static RelationshipNote noteFor(
    Map<RelValue, double> deltas,
    TimelineKind category, {
    String? kindId,
    String? evidence,
    String? reason,
    String? entryId,
  }) {
    final main = _mainDelta(deltas)!;
    final up = deltas[main]! > 0;
    final small = deltas[main]!.abs() < 2;
    final text = main == RelValue.tension
        ? (up ? 'Tension rose' : 'Tension eased')
        : '${main.label} ${up ? 'grew' : 'slipped'}${small ? ' a little' : ''}';
    final story = category == TimelineKind.setback
        ? 'A distance opened between you.'
        : category == TimelineKind.reconcile
        ? 'Something mended, a little.'
        : 'Something shifted between you.';
    return RelationshipNote(
      text: text,
      story: story,
      entryId: entryId,
      kindId: kindId,
      evidence: evidence,
      reason: reason,
    );
  }

  /// Lower-case words only, so repeats and quotes compare reliably.
  static String normalise(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Tags the engine uses to decide what a locked fact forbids.
  static List<String> inferFactTags(String text) {
    final t = text.toLowerCase();
    final tags = <String>[];
    if (RegExp(
          r'\b(siblings?|brothers?|sisters?|mother|father|parents?|cousins?|related by blood)\b',
        ).hasMatch(t) &&
        !RegExp(r'\bnot (related|siblings?)\b').hasMatch(t)) {
      tags.add('family');
    }
    if (RegExp(r'\b(just friends|only friends|platonic)\b').hasMatch(t)) {
      tags.add('platonic-only');
    }
    if (RegExp(
      r'\b(never breaks? (a |their |her |his )?promises?|always keeps? (a |their |her |his )?(promise|word)s?)\b',
    ).hasMatch(t)) {
      tags.add('keeps-promises');
    }
    if (RegExp(r'\b(loyal|never betray|would never betray)\b').hasMatch(t)) {
      tags.add('loyal');
    }
    return tags;
  }
}
