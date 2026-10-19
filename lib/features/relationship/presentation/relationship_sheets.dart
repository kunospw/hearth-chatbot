import 'package:flutter/material.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/sheets.dart';
import '../domain/relationship_bands.dart';
import '../domain/relationship_models.dart';

Color meterColor(BuildContext context, RelValue v) {
  final c = context.hc;
  return switch (v) {
    RelValue.trust => c.meterTrust,
    RelValue.affection => c.meterAffection,
    RelValue.attraction => c.meterAttraction,
    RelValue.tension => c.meterTension,
  };
}

// ── Adjust ───────────────────────────────────────────────────────────────

class AdjustResult {
  const AdjustResult(this.values, this.reason);
  final Values values;
  final String reason;
}

/// "Adjust the relationship": set the four values yourself. The correction goes
/// in the timeline and becomes the new starting point.
Future<AdjustResult?> showAdjustSheet(
  BuildContext context,
  Relationship r,
  String first,
) {
  return showHearthSheet<AdjustResult>(
    context,
    builder: (_) => _AdjustSheet(r: r, first: first),
  );
}

class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({required this.r, required this.first});

  final Relationship r;
  final String first;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late Values _v = Values(
    trust: widget.r.values.trust.roundToDouble(),
    affection: widget.r.values.affection.roundToDouble(),
    attraction: widget.r.values.attraction.roundToDouble(),
    tension: widget.r.values.tension.roundToDouble(),
  );
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    final c = context.hc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'Adjust the relationship'),
        Text(
          'Corrections go in the timeline and become the new starting point. '
          '${widget.first} never sees numbers — only how to act.',
          style: t.body.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: Space.md),
        for (final k in RelValue.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        k.label,
                        style: t.label.copyWith(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${_v[k].round()} · ${wordFor(k, _v[k])}',
                      style: t.caption.copyWith(color: c.primaryInk),
                    ),
                  ],
                ),
                Semantics(
                  label: k.label,
                  child: Slider(
                    value: _v[k],
                    min: 0,
                    max: 100,
                    divisions: 100,
                    semanticFormatterCallback: (v) =>
                        '${v.round()}, ${wordFor(k, v)}',
                    onChanged: (x) =>
                        setState(() => _v = _v.withValue(k, x.roundToDouble())),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.sm),
        Text.rich(
          TextSpan(
            style: t.label.copyWith(fontSize: 14),
            children: [
              const TextSpan(text: 'What happened? '),
              TextSpan(
                text: 'optional',
                style: t.body.copyWith(color: c.textSubtle),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm - 2),
        TextField(
          controller: _reason,
          textCapitalization: TextCapitalization.sentences,
          style: t.chat,
          decoration: const InputDecoration(
            hintText: 'e.g. We made up off-screen',
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(AdjustResult(_v, _reason.text)),
          child: const Text('Save correction'),
        ),
      ],
    );
  }
}

// ── Stages ───────────────────────────────────────────────────────────────

class StagesResult {
  const StagesResult(this.names, this.current, this.lock);
  final List<String> names;
  final int current;
  final bool lock;
}

/// "Edit stages": rename them, tap a circle to say where you are now, and lock it.
Future<StagesResult?> showStagesSheet(BuildContext context, Relationship r) {
  return showHearthSheet<StagesResult>(
    context,
    builder: (_) => _StagesSheet(r: r),
  );
}

class _StagesSheet extends StatefulWidget {
  const _StagesSheet({required this.r});

  final Relationship r;

  @override
  State<_StagesSheet> createState() => _StagesSheetState();
}

class _StagesSheetState extends State<_StagesSheet> {
  late final List<TextEditingController> _names = [
    for (final s in widget.r.stages) TextEditingController(text: s),
  ];
  late int _current = widget.r.stageIdx;
  late bool _lock = widget.r.stageLocked;

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    final c = context.hc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'Edit stages'),
        Text(
          'Name the stages for this story — they don’t have to be romantic. '
          'Tap the circle to set where you are now.',
          style: t.body.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: Space.md),
        for (var i = 0; i < _names.length; i++)
          Row(
            children: [
              Semantics(
                button: true,
                inMutuallyExclusiveGroup: true,
                checked: _current == i,
                label: 'Make stage ${i + 1} the current stage',
                excludeSemantics: true,
                onTap: () => setState(() => _current = i),
                child: InkResponse(
                  onTap: () => setState(() => _current = i),
                  radius: Hit.inline / 2,
                  child: SizedBox(
                    width: Hit.inline,
                    height: Hit.inline,
                    child: Center(
                      child: AnimatedContainer(
                        duration: Motion.press,
                        width: Space.xl,
                        height: Space.xl,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _current == i ? c.primaryInk : c.outline,
                            width: Sizes.stroke,
                          ),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: Motion.press,
                            width: _current == i ? Space.md : 0,
                            height: _current == i ? Space.md : 0,
                            decoration: BoxDecoration(
                              color: c.primaryInk,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Semantics(
                    label: 'Stage ${i + 1} name',
                    child: TextField(
                      controller: _names[i],
                      textCapitalization: TextCapitalization.words,
                      style: t.body,
                      decoration: const InputDecoration(
                        constraints: BoxConstraints(minHeight: Hit.primary - 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: Space.sm),
        SwitchRow(
          title: 'Lock the current stage',
          subtitle:
              'The story can still shift feelings, but the stage stays put.',
          value: _lock,
          onChanged: (v) => setState(() => _lock = v),
        ),
        const SizedBox(height: Space.sm),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            StagesResult([for (final n in _names) n.text], _current, _lock),
          ),
          child: const Text('Save stages'),
        ),
      ],
    );
  }
}

// ── Fact ─────────────────────────────────────────────────────────────────

class FactResult {
  const FactResult(this.text, this.locked);
  final String text;
  final bool locked;
}

Future<FactResult?> showFactSheet(BuildContext context) {
  return showHearthSheet<FactResult>(
    context,
    builder: (_) => const _FactSheet(),
  );
}

class _FactSheet extends StatefulWidget {
  const _FactSheet();

  @override
  State<_FactSheet> createState() => _FactSheetState();
}

class _FactSheetState extends State<_FactSheet> {
  final _text = TextEditingController();
  bool _locked = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'Add an established fact'),
        Text('What’s true between you?', style: t.label.copyWith(fontSize: 14)),
        const SizedBox(height: Space.sm - 2),
        TextField(
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          style: t.chat,
          decoration: const InputDecoration(
            hintText: 'e.g. You saved each other’s lives on the north rocks.',
          ),
        ),
        const SizedBox(height: Space.sm),
        SwitchRow(
          title: 'Lock it',
          subtitle:
              'Locked facts can’t be changed or contradicted by the story.',
          value: _locked,
          onChanged: (v) => setState(() => _locked = v),
        ),
        const SizedBox(height: Space.sm),
        FilledButton(
          onPressed: _text.text.trim().isEmpty
              ? null
              : () =>
                    Navigator.of(context)
                        .pop(FactResult(_text.text.trim(), _locked)),
          child: const Text('Save fact'),
        ),
      ],
    );
  }
}
