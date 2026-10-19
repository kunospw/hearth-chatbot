import 'package:flutter/material.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/sheets.dart';
import '../domain/library_models.dart';

// ── Memory ───────────────────────────────────────────────────────────────

/// What the memory sheet decided.
sealed class MemorySheetResult {
  const MemorySheetResult();
}

class MemorySaved extends MemorySheetResult {
  const MemorySaved({
    required this.text,
    required this.category,
    required this.pinned,
  });
  final String text;
  final MemoryCategory category;
  final bool pinned;
}

class MemoryDeleted extends MemorySheetResult {
  const MemoryDeleted();
}

/// Add or edit a memory. Save stays disabled while the text is empty. Editing
/// also offers Delete (the caller shows an Undo). Null if dismissed.
Future<MemorySheetResult?> showMemorySheet(
  BuildContext context, {
  Memory? memory,
}) {
  return showHearthSheet<MemorySheetResult>(
    context,
    builder: (_) => _MemorySheet(memory: memory),
  );
}

class _MemorySheet extends StatefulWidget {
  const _MemorySheet({this.memory});

  final Memory? memory;

  @override
  State<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<_MemorySheet> {
  late final _text = TextEditingController(text: widget.memory?.text ?? '');
  late MemoryCategory _category =
      widget.memory?.category ?? MemoryCategory.important;
  late bool _pinned = widget.memory?.pinned ?? false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSave => _text.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: widget.memory == null ? 'Add a memory' : 'Edit memory',
        ),
        Text(
          'What should they remember?',
          style: t.label.copyWith(fontSize: 14),
        ),
        const SizedBox(height: Space.sm - 2),
        TextField(
          controller: _text,
          autofocus: widget.memory == null,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          style: t.chat,
          decoration: const InputDecoration(
            hintText: 'e.g. Vesper keeps the lamp key on a red cord.',
          ),
        ),
        const SizedBox(height: Space.lg),
        Text('Type', style: t.label.copyWith(fontSize: 14)),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final c in MemoryCategory.values)
              HearthChip(
                label: c.shortLabel,
                selected: _category == c,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        SwitchRow(
          title: 'Always remember',
          subtitle: 'Pinned memories are in every conversation.',
          value: _pinned,
          onChanged: (v) => setState(() => _pinned = v),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            if (widget.memory != null) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.hc.danger,
                  side: BorderSide(color: context.hc.danger),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(const MemoryDeleted()),
                child: const Text('Delete'),
              ),
              const SizedBox(width: Space.sm),
            ],
            Expanded(
              child: FilledButton(
                onPressed: _canSave
                    ? () => Navigator.of(context).pop(
                        MemorySaved(
                          text: _text.text.trim(),
                          category: _category,
                          pinned: _pinned,
                        ),
                      )
                    : null,
                child: const Text('Save memory'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Universe ─────────────────────────────────────────────────────────────

class UniverseSheetResult {
  const UniverseSheetResult({required this.name, required this.description});
  final String name;
  final String description;
}

/// Create or edit a universe: a name and "the setting in a sentence or two".
Future<UniverseSheetResult?> showUniverseSheet(
  BuildContext context, {
  Universe? universe,
}) {
  return showHearthSheet<UniverseSheetResult>(
    context,
    builder: (_) => _UniverseSheet(universe: universe),
  );
}

class _UniverseSheet extends StatefulWidget {
  const _UniverseSheet({this.universe});

  final Universe? universe;

  @override
  State<_UniverseSheet> createState() => _UniverseSheetState();
}

class _UniverseSheetState extends State<_UniverseSheet> {
  late final _name = TextEditingController(text: widget.universe?.name ?? '');
  late final _desc = TextEditingController(
    text: widget.universe?.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: widget.universe == null
              ? 'Create a universe'
              : 'Edit universe',
        ),
        Text('Name', style: t.label.copyWith(fontSize: 14)),
        const SizedBox(height: Space.sm - 2),
        TextField(
          controller: _name,
          autofocus: widget.universe == null,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          style: t.chat,
          decoration: const InputDecoration(
            hintText: 'e.g. The Drowned Kingdoms',
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          'The setting in a sentence or two',
          style: t.label.copyWith(fontSize: 14),
        ),
        const SizedBox(height: Space.sm - 2),
        TextField(
          controller: _desc,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          style: t.chat,
          decoration: const InputDecoration(
            hintText: 'Where and when is it? What makes it different?',
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  UniverseSheetResult(
                    name: _name.text.trim(),
                    description: _desc.text.trim(),
                  ),
                ),
          child: const Text('Save universe'),
        ),
      ],
    );
  }
}

// ── Persona ──────────────────────────────────────────────────────────────

class PersonaSheetResult {
  const PersonaSheetResult({required this.name, required this.description});
  final String name;
  final String description;
}

Future<PersonaSheetResult?> showPersonaSheet(BuildContext context) {
  return showHearthSheet<PersonaSheetResult>(
    context,
    builder: (_) => const _PersonaSheet(),
  );
}

class _PersonaSheet extends StatefulWidget {
  const _PersonaSheet();

  @override
  State<_PersonaSheet> createState() => _PersonaSheetState();
}

class _PersonaSheetState extends State<_PersonaSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'New persona'),
        Text('Name', style: t.label.copyWith(fontSize: 14)),
        const SizedBox(height: Space.sm - 2),
        TextField(
          controller: _name,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          style: t.chat,
          decoration: const InputDecoration(hintText: 'e.g. Wren'),
        ),
        const SizedBox(height: Space.lg),
        Text('Who are they?', style: t.label.copyWith(fontSize: 14)),
        const SizedBox(height: Space.sm - 2),
        TextField(
          controller: _desc,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          style: t.chat,
          decoration: const InputDecoration(
            hintText: 'A travelling cartographer with a borrowed coat',
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  PersonaSheetResult(
                    name: _name.text.trim(),
                    description: _desc.text.trim(),
                  ),
                ),
          child: const Text('Save persona'),
        ),
      ],
    );
  }
}
