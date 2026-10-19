import 'package:flutter/material.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/rich_roleplay_text.dart';

/// "Vesper is writing…" with three pulsing dots (chat), shown until the first
/// words arrive.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key, required this.label, this.story = false});

  final String label;

  /// Story mode: an italic serif "The story continues…" line instead.
  final bool story;

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final style = widget.story
        ? context.ht.story.copyWith(
            fontStyle: FontStyle.italic,
            color: c.textSubtle,
          )
        : context.ht.body.copyWith(color: c.textSubtle);
    return Semantics(
      liveRegion: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(widget.label, style: style)),
              const SizedBox(width: Space.sm),
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: Space.xs),
                        child: Opacity(
                          opacity: reduceMotion(context) ? 0.6 : _dot(i),
                          child: Container(
                            width: Space.sm - 1,
                            height: Space.sm - 1,
                            decoration: BoxDecoration(
                              color: c.textSubtle,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _dot(int i) {
    final t = (_c.value - i * 0.18) % 1.0;
    return 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
  }
}

/// The user's message in Chat: the only bubble. Soft-burgundy fill, right
/// aligned, never wider than 85% of the row. Long-press (or ⋯) for Copy/Edit.
class UserBubble extends StatelessWidget {
  const UserBubble({
    super.key,
    required this.text,
    required this.style,
    this.onMore,
  });

  final String text;
  final TextStyle style;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
      child: LayoutBuilder(
        builder: (context, box) {
          final menu = onMore == null ? 0.0 : Hit.inline;
          final maxBubble = box.maxWidth * 0.85 - menu;
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (onMore != null)
                IconButton(
                  tooltip: 'More options for your message',
                  icon: const Icon(Icons.more_horiz),
                  onPressed: onMore,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Hit.inline),
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubble),
                child: GestureDetector(
                  onLongPress: onMore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg,
                      vertical: Space.md,
                    ),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: RichRoleplayText(text, style: style),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Inline editor that replaces a message while it is being edited.
class InlineEditor extends StatefulWidget {
  const InlineEditor({
    super.key,
    required this.initial,
    required this.style,
    required this.onSave,
    required this.onCancel,
  });

  final String initial;
  final TextStyle style;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<InlineEditor> createState() => _InlineEditorState();
}

class _InlineEditorState extends State<InlineEditor> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            minLines: 2,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            style: widget.style.copyWith(color: context.hc.text),
            decoration: const InputDecoration(hintText: 'Edit message'),
          ),
          const SizedBox(height: Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: Space.sm),
              FilledButton(
                // Disabled while empty, so no toast is needed (and none covers Save).
                onPressed: _c.text.trim().isEmpty
                    ? null
                    : () => widget.onSave(_c.text),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A user turn in Story mode: a small "YOU" label over italic serif text.
class StoryYouBlock extends StatelessWidget {
  const StoryYouBlock({
    super.key,
    required this.text,
    required this.style,
    this.onMore,
  });

  final String text;
  final TextStyle style;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs, bottom: Space.xl),
      child: GestureDetector(
        onLongPress: onMore,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg - 2,
            vertical: Space.md,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.button),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'YOU',
                      style: context.ht.overline.copyWith(
                        color: c.primaryInk,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (onMore != null)
                    IconButton(
                      tooltip: 'More options for your turn',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: onMore,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(Hit.inline),
                      ),
                    ),
                ],
              ),
              Text(
                text.replaceAll('*', ''),
                style: style.copyWith(
                  fontStyle: FontStyle.italic,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Stopped" note under a reply whose writing was cut short.
class StoppedCaption extends StatelessWidget {
  const StoppedCaption({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xs),
    child: Text('Stopped', style: context.ht.caption),
  );
}
