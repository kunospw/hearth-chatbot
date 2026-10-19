import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/toast.dart';
import '../../../data/mock/mock_scenario.dart';
import '../../settings/data/model_usage.dart';

/// Debug-only design reference: type scale, colour tokens, theme toggle.
/// Not part of the spec; registered only when `kDebugMode` is true.
class DevScreen extends ConsumerWidget {
  const DevScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final t = context.ht;
    final choice = ref.watch(themeChoiceProvider);

    final swatches = <(String, Color)>[
      ('bg', c.bg),
      ('surface', c.surface),
      ('surfaceRaised', c.surfaceRaised),
      ('outline', c.outline),
      ('text', c.text),
      ('textMuted', c.textMuted),
      ('textSubtle', c.textSubtle),
      ('primary (fill only)', c.primary),
      ('primaryPressed', c.primaryPressed),
      ('primaryInk', c.primaryInk),
      ('primarySoft', c.primarySoft),
      ('pin', c.pin),
      ('danger', c.danger),
      ('dangerFill', c.dangerFill),
      ('ok', c.ok),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Design reference')),
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.devGallery),
            icon: const Icon(Icons.widgets_outlined),
            label: const Text('Widget gallery'),
          ),
          const SizedBox(height: Space.xl),
          Text('Mock data scenario (home and chats)', style: t.overline),
          const SizedBox(height: Space.sm),
          HearthSegmented<MockScenario>(
            options: {for (final s in MockScenario.values) s: s.label},
            value: ref.watch(mockScenarioProvider),
            onChanged: (s) => ref.read(mockScenarioProvider.notifier).state = s,
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              OutlinedButton(
                onPressed: () {
                  ref.read(mockFailNextReplyProvider.notifier).state = true;
                  showToast(context, 'The next reply will fail as if offline');
                },
                child: const Text('Fail the next reply'),
              ),
              OutlinedButton(
                onPressed: () {
                  ref.invalidate(modelUsageProvider);
                  ref.read(selectedModelIdProvider.notifier).select('ember');
                  showToast(context, 'Model limits reset (Ember: 2 left)');
                },
                child: const Text('Reset model limits'),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('Theme', style: t.overline),
          const SizedBox(height: Space.sm),
          SegmentedButton<HearthThemeChoice>(
            showSelectedIcon: false,
            segments: [
              for (final o in HearthThemeChoice.values)
                ButtonSegment(value: o, label: Text(o.label)),
            ],
            selected: {choice},
            onSelectionChanged: (s) =>
                ref.read(themeChoiceProvider.notifier).set(s.first),
          ),
          const SizedBox(height: Space.xl),
          Text('Type scale', style: t.overline),
          const SizedBox(height: Space.md),
          for (final sample in <(String, TextStyle)>[
            ('Display 30 · Newsreader', t.display),
            ('Title 19 · Newsreader', t.title),
            (
              'Story 19 / 1.72. The lighthouse door opens before you can knock.',
              t.story,
            ),
            (
              'Chat 16 / 1.62 · Figtree. You came up the cliff path in this?',
              t.chat,
            ),
            ('Label 16 · 600', t.label),
            ('Body 15 / 1.5', t.body),
            ('OVERLINE 13', t.overline),
            ('Caption 13 / 1.45', t.caption),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Text(sample.$1, style: sample.$2),
            ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '*action* ',
                  style: t.story.copyWith(
                    fontStyle: FontStyle.italic,
                    color: c.textMuted,
                  ),
                ),
                TextSpan(
                  text: '“dialogue” ',
                  style: t.story.copyWith(color: c.dialogue),
                ),
                TextSpan(
                  text: 'narration',
                  style: t.story.copyWith(color: c.narration),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Text('Colours', style: t.overline),
          const SizedBox(height: Space.sm),
          for (final (name, color) in swatches)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                children: [
                  Container(
                    width: Hit.primary,
                    height: Space.xxl,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(Radii.field),
                      border: Border.all(color: c.outline),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Text(name, style: t.body),
                  const Spacer(),
                  Text(
                    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                    style: t.caption,
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.lg),
          FilledButton(onPressed: () {}, child: const Text('Primary action')),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              TextButton(onPressed: () {}, child: const Text('Link action')),
              const SizedBox(width: Space.sm),
              OutlinedButton(onPressed: () {}, child: const Text('Secondary')),
            ],
          ),
        ],
      ),
    );
  }
}
