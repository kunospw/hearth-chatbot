import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../data/ai_prefs.dart';
import '../data/model_usage.dart';
import '../domain/ai_model.dart';
import '../data/model_repository.dart';

/// AI settings: model, response length, writing style and creativity in plain
/// words. The technical controls live only in the collapsed Advanced section.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  bool _advancedOpen = false;

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    final c = context.hc;
    final prefs = ref.watch(aiPrefsProvider);
    final notifier = ref.read(aiPrefsProvider.notifier);

    Widget section(String title, List<Widget> kids) => Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Overline(title),
          const SizedBox(height: Space.sm),
          ...kids,
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(title: 'AI settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.xxl,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg + Space.sm),
                    child: Text(
                      'These apply to every chat. Change them anytime — '
                      'nothing here affects what’s already written.',
                      style: t.body.copyWith(color: c.textMuted),
                    ),
                  ),
                  section('Model', [const _ModelList()]),
                  section('Response length', [
                    HearthSegmented<ReplyLength>(
                      semanticLabel: 'Response length',
                      options: {for (final l in ReplyLength.values) l: l.label},
                      value: prefs.length,
                      onChanged: notifier.setLength,
                    ),
                  ]),
                  section('Writing style', [
                    HearthSegmented<WritingStyle>(
                      semanticLabel: 'Writing style',
                      options: {
                        for (final s in WritingStyle.values) s: s.label,
                      },
                      value: prefs.style,
                      onChanged: notifier.setStyle,
                    ),
                  ]),
                  section('Creativity', [
                    HearthSegmented<Creativity>(
                      semanticLabel: 'Creativity',
                      options: {for (final s in Creativity.values) s: s.label},
                      value: prefs.creativity,
                      onChanged: notifier.setCreativity,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      prefs.creativity.hint,
                      style: t.body.copyWith(color: c.textMuted),
                    ),
                  ]),
                  _Advanced(
                    open: _advancedOpen,
                    onToggle: () =>
                        setState(() => _advancedOpen = !_advancedOpen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.sm,
        Space.gutter,
        Space.xs,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.characters),
          ),
          Expanded(
            child: Text(
              title,
              style: context.ht.display.copyWith(fontSize: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelList extends ConsumerWidget {
  const _ModelList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final models = ref.watch(modelsProvider);
    final selected = ref.watch(selectedModelIdProvider);

    return models.when(
      // Status shimmer while the availability loads.
      loading: () => const Skeleton(
        label: 'Loading models',
        child: Column(
          children: [
            SkeletonBox(height: 104, radius: Radii.card),
            SizedBox(height: Space.sm),
            SkeletonBox(height: 104, radius: Radii.card),
            SizedBox(height: Space.sm),
            SkeletonBox(height: 104, radius: Radii.card),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in list) ...[
            _ModelCard(model: m, selected: m.id == selected),
            const SizedBox(height: Space.sm),
          ],
          Text(
            'Free models have a daily reply limit. It resets every day at $resetsAtLabel.',
            style: context.ht.caption.copyWith(color: c.textSubtle),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends ConsumerWidget {
  const _ModelCard({required this.model, required this.selected});

  final AiModel model;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final status = ref.watch(modelStatusProvider(model.id));
    return RadioCard(
      title: model.name,
      subtitle: model.description,
      status: status.line(model),
      statusColor: status.available ? c.ok : (model.busy ? c.pin : c.danger),
      enabled: status.available,
      selected: selected,
      onTap: () {
        ref.read(selectedModelIdProvider.notifier).select(model.id);
        showToast(context, 'Switched to ${model.name}');
      },
    );
  }
}

class _Advanced extends ConsumerWidget {
  const _Advanced({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final t = context.ht;
    final adv = ref.watch(aiPrefsProvider).advanced;
    final notifier = ref.read(aiPrefsProvider.notifier);

    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card - 2),
        side: BorderSide(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: 'Advanced',
            excludeSemantics: true,
            onTap: onToggle,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Hit.primary + Space.md,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advanced',
                              style: t.label.copyWith(fontSize: 15),
                            ),
                            Text(
                              'Technical controls for fine-tuning. Safe to ignore.',
                              style: t.caption,
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: reduceMotion(context)
                            ? Duration.zero
                            : Motion.press,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion(context) ? Duration.zero : Motion.sheet,
            curve: Motion.emphasizedDecelerate,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.xs,
                      Space.lg,
                      Space.lg + 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SliderRow(
                          label: 'Temperature',
                          shown: adv.temperature.toStringAsFixed(2),
                          help: 'Randomness of word choice. Creativity sets this for you.',
                          min: 0,
                          max: 2,
                          divisions: 40,
                          value: adv.temperature,
                          onChanged: (v) => notifier.setAdvanced(
                            adv.copyWith(temperature: v),
                          ),
                        ),
                        _SliderRow(
                          label: 'Max reply tokens',
                          shown: '${adv.maxTokens}',
                          help: 'Hard cap on reply length. Response length sets this for you.',
                          min: 100,
                          max: 2000,
                          divisions: 38,
                          value: adv.maxTokens.toDouble(),
                          onChanged: (v) => notifier.setAdvanced(
                            adv.copyWith(maxTokens: v.round()),
                          ),
                        ),
                        _SliderRow(
                          label: 'Context depth (messages)',
                          shown: '${adv.contextDepth}',
                          help: 'How many recent messages are sent along with memories.',
                          min: 10,
                          max: 200,
                          divisions: 19,
                          value: adv.contextDepth.toDouble(),
                          onChanged: (v) => notifier.setAdvanced(
                            adv.copyWith(contextDepth: v.round()),
                          ),
                        ),
                        _SliderRow(
                          label: 'Repetition penalty',
                          shown: adv.repetitionPenalty.toStringAsFixed(2),
                          help: 'Discourages repeating the same phrases.',
                          min: 1,
                          max: 1.5,
                          divisions: 50,
                          value: adv.repetitionPenalty,
                          onChanged: (v) => notifier.setAdvanced(
                            adv.copyWith(repetitionPenalty: v),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            notifier.resetAdvanced();
                            showToast(context, 'Advanced settings reset');
                          },
                          child: const Text('Reset to defaults'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.shown,
    required this.help,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String shown;
  final String help;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: t.label.copyWith(fontSize: 14)),
              ),
              Text(shown, style: t.body.copyWith(color: c.primaryInk)),
            ],
          ),
          Semantics(
            label: label,
            value: shown,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              semanticFormatterCallback: (_) => shown,
              onChanged: onChanged,
            ),
          ),
          Text(help, style: t.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
