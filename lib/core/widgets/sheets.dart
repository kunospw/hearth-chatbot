import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

/// Opens a Hearth bottom sheet: rounded 26dp top corners, drag handle, the
/// theme scrim, 250ms emphasized-decelerate, and content inside a bottom
/// SafeArea that also clears the keyboard. Scrolls if content is tall.
Future<T?> showHearthSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: Reading.storyMaxWidth),
    sheetAnimationStyle: const AnimationStyle(
      duration: Motion.sheet,
      reverseDuration: Motion.press,
      curve: Motion.emphasizedDecelerate,
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.lg,
          ),
          child: builder(ctx),
        ),
      ),
    ),
  );
}

/// Title (and optional message) at the top of a sheet.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.ht.title),
        if (message != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            message!,
            style: context.ht.body.copyWith(color: context.hc.textMuted),
          ),
        ],
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

/// One row in an [OptionsSheet].
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.meta,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool destructive;

  /// Secondary text on the right, e.g. the current model name.
  final String? meta;
}

/// A list of actions (for example the chat ⋯ menu). Pops with the tapped
/// option's value; null if dismissed.
Future<T?> showOptionsSheet<T>(
  BuildContext context, {
  String? title,
  required List<SheetOption<T>> options,
}) {
  return showHearthSheet<T>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) SheetHeader(title: title),
        for (final o in options)
          _OptionRow(
            icon: o.icon,
            label: o.label,
            destructive: o.destructive,
            meta: o.meta,
            onTap: () => Navigator.of(ctx).pop(o.value),
          ),
      ],
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.destructive,
    required this.onTap,
    this.meta,
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final String? meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final color = destructive ? c.danger : c.text;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.field),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Hit.primary),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Space.md,
            horizontal: Space.xs,
          ),
          child: Row(
            children: [
              Icon(icon, color: destructive ? c.danger : c.textMuted),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Text(
                  label,
                  style: context.ht.body.copyWith(color: color),
                ),
              ),
              if (meta != null && meta!.isNotEmpty) ...[
                const SizedBox(width: Space.md),
                Flexible(
                  child: Text(
                    meta!,
                    textAlign: TextAlign.end,
                    style: context.ht.caption.copyWith(color: c.textSubtle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum DiscardChoice { saveDraft, keepEditing, discard }

/// "Leave with unsaved changes?" Save draft / Keep editing / Discard.
/// Dismissing the sheet counts as Keep editing.
Future<DiscardChoice> showDiscardSheet(
  BuildContext context, {
  String title = 'Leave without saving?',
  String message = 'You have changes that haven’t been saved.',
}) async {
  final r = await showHearthSheet<DiscardChoice>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title, message: message),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(DiscardChoice.saveDraft),
          child: const Text('Save draft'),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(DiscardChoice.keepEditing),
          child: const Text('Keep editing'),
        ),
        const SizedBox(height: Space.sm),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: ctx.hc.danger,
            minimumSize: const Size.fromHeight(Hit.primary),
          ),
          onPressed: () => Navigator.of(ctx).pop(DiscardChoice.discard),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return r ?? DiscardChoice.keepEditing;
}

/// Confirmation before a destructive, hard-to-undo action. The safe option
/// comes first. Returns true only if the user confirms the deletion.
Future<bool> showConfirmDeleteSheet(
  BuildContext context, {
  required String title,
  String? message,
  String keepLabel = 'Keep it',
  String deleteLabel = 'Delete',
}) async {
  final r = await showHearthSheet<bool>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title, message: message),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(keepLabel),
        ),
        const SizedBox(height: Space.sm),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.hc.dangerFill,
            foregroundColor: ctx.hc.onPrimary,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(deleteLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// One text field with a Save button: rename a chat, name a persona, etc.
/// Returns the trimmed text, or null if dismissed. Save stays disabled while
/// the field is empty.
Future<String?> showTextInputSheet(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String confirmLabel = 'Save',
}) {
  return showHearthSheet<String>(
    context,
    builder: (ctx) => _TextInputSheet(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String? hint;
  final String confirmLabel;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final _c = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _c.text.trim();
    if (t.isNotEmpty) Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: widget.title),
        TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() {}),
          style: context.ht.body,
          decoration: InputDecoration(hintText: widget.hint),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(
          onPressed: _c.text.trim().isEmpty ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
