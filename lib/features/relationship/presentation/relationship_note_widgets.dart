import 'package:flutter/material.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../domain/relationship_models.dart';

/// The muted line under a message when something shifted between you:
/// "Trust grew a little · Why?". Tapping it opens the journal at that moment.
/// Words only; numbers never appear in a chat.
class RelationshipNoteLine extends StatelessWidget {
  const RelationshipNoteLine({
    super.key,
    required this.note,
    required this.onOpen,
    this.alignEnd = false,
  });

  final RelationshipNote note;
  final VoidCallback onOpen;

  /// Under your own (right-aligned) bubble.
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    final c = context.hc;
    final waiting = note.entryId == null;
    final label = waiting ? note.text : '${note.text} · Why?';
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: waiting
            ? '${note.text}. Open the relationship journal to review it'
            : '${note.text}. Why? Open the relationship journal',
        excludeSemantics: true,
        onTap: onOpen,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.field),
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Hit.inline),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Align(
                alignment: Alignment.center,
                widthFactor: 1,
                child: Text(
                  label,
                  style: t.caption.copyWith(color: c.textSubtle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Story mode's quiet version: a centred italic serif line,
/// "— Something shifted between you. —".
class RelationshipOrnament extends StatelessWidget {
  const RelationshipOrnament({
    super.key,
    required this.note,
    required this.onOpen,
  });

  final RelationshipNote note;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    final c = context.hc;
    return Center(
      child: Semantics(
        button: true,
        label: '${note.story} Open the relationship journal',
        excludeSemantics: true,
        onTap: onOpen,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.field),
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Hit.inline),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '— ${note.story} —',
                  textAlign: TextAlign.center,
                  style: t.story.copyWith(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: c.textSubtle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
