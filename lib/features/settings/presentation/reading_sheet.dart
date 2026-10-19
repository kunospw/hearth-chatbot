import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/rich_roleplay_text.dart';
import '../../../core/widgets/sheets.dart';
import '../../chat/domain/chat_models.dart';
import '../data/reading_prefs.dart';

/// "Text & reading" (Chat) / "Reading & writing" (Story): text size with
/// A− / A+, line spacing, and a live preview. Story also has Narration and
/// Pacing. Changes apply immediately and are remembered.
Future<void> showReadingSheet(BuildContext context, ChatMode mode) {
  return showHearthSheet<void>(
    context,
    builder: (_) => ReadingSheetBody(mode: mode),
  );
}

const _chatPreview =
    '*The great lamp begins its slow turn.* "Throwing light across the room and away again."';
const _storyPreview =
    'The great lamp begins its slow turn, throwing light across the room and away again.';

class ReadingSheetBody extends ConsumerWidget {
  const ReadingSheetBody({super.key, required this.mode});

  final ChatMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final t = context.ht;
    final prefs = ref.watch(readingPrefsProvider);
    final notifier = ref.read(readingPrefsProvider.notifier);
    final story = mode == ChatMode.story;
    final size = story ? prefs.storySize : prefs.chatSize;
    final range = story ? Reading.storySize : Reading.chatSize;

    void setSize(double v) =>
        story ? notifier.setStorySize(v) : notifier.setChatSize(v);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Text(text, style: t.label.copyWith(fontSize: 15)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: story ? 'Reading & writing' : 'Text & reading'),
        Row(
          children: [
            Expanded(
              child: Text('Text size', style: t.label.copyWith(fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.all(Space.xs),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepButton(
                    tooltip: 'Smaller text',
                    label: 'A−',
                    fontSize: 15,
                    onPressed: size > range.min
                        ? () => setSize(size - 1)
                        : null,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: Space.xxl + Space.md,
                    ),
                    child: Text(
                      '${size.round()}',
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(color: c.textMuted),
                    ),
                  ),
                  _StepButton(
                    tooltip: 'Larger text',
                    label: 'A+',
                    fontSize: 20,
                    onPressed: size < range.max
                        ? () => setSize(size + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        label('Line spacing'),
        HearthSegmented<int>(
          semanticLabel: 'Line spacing',
          options: {
            for (var i = 0; i < lineSpacingLabels.length; i++)
              i: lineSpacingLabels[i],
          },
          value: prefs.lineSpacing,
          onChanged: notifier.setLineSpacing,
        ),
        const SizedBox(height: Space.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md + 2,
          ),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(Radii.button),
          ),
          child: RichRoleplayText(
            story ? _storyPreview : _chatPreview,
            style: story
                ? t.storyStyle(
                    size: prefs.storySize,
                    lineHeight: prefs.storyLineHeight,
                  )
                : t.chatStyle(
                    size: prefs.chatSize,
                    lineHeight: prefs.chatLineHeight,
                  ),
          ),
        ),
        if (story) ...[
          const SizedBox(height: Space.lg),
          label('Narration'),
          HearthSegmented<Narration>(
            semanticLabel: 'Narration',
            options: {for (final n in Narration.values) n: n.label},
            value: prefs.narration,
            onChanged: notifier.setNarration,
          ),
          const SizedBox(height: Space.lg),
          label('Pacing'),
          HearthSegmented<Pacing>(
            semanticLabel: 'Pacing',
            options: {for (final p in Pacing.values) p: p.label},
            value: prefs.pacing,
            onChanged: notifier.setPacing,
          ),
          const SizedBox(height: Space.md),
          Text(
            'Narration and pacing shape new passages. What’s already written stays as it is.',
            style: t.caption,
          ),
        ],
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.tooltip,
    required this.label,
    required this.fontSize,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final double fontSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(Hit.primary, Hit.inline),
        foregroundColor: context.hc.text,
        disabledForegroundColor: context.hc.textSubtle,
        padding: EdgeInsets.zero,
      ),
      child: Tooltip(
        message: tooltip,
        child: Text(
          label,
          semanticsLabel: tooltip,
          style: context.ht.title.copyWith(fontSize: fontSize, color: null),
        ),
      ),
    );
  }
}
