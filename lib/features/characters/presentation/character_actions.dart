import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/toast.dart';
import '../../chat/data/conversation_repository.dart';
import '../data/character_repository.dart';
import '../domain/character.dart';

enum _CharAction { open, edit, archive, delete }

/// The ⋯ menu of a character: open, edit, archive (hide it, keep everything)
/// and delete (remove it and all its chats).
Future<void> showCharacterOptions(
  BuildContext context,
  WidgetRef ref,
  Character ch,
) async {
  final chats = [
    for (final c in ref.read(conversationsProvider).valueOrNull ?? const [])
      if (c.characterId == ch.id) c,
  ];
  final choice = await showOptionsSheet<_CharAction>(
    context,
    title: ch.name,
    options: [
      SheetOption(
        value: _CharAction.open,
        label: chats.isEmpty
            ? 'Open profile'
            : 'Open profile and ${chats.length} ${chats.length == 1 ? 'chat' : 'chats'}',
        icon: Icons.person_outline,
      ),
      const SheetOption(
        value: _CharAction.edit,
        label: 'Edit',
        icon: Icons.edit_outlined,
      ),
      SheetOption(
        value: _CharAction.archive,
        label: ch.archived ? 'Unarchive' : 'Archive',
        icon: ch.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
      ),
      const SheetOption(
        value: _CharAction.delete,
        label: 'Delete character…',
        icon: Icons.delete_outline,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted || choice == null) return;
  final notifier = ref.read(charactersProvider.notifier);
  switch (choice) {
    case _CharAction.open:
      context.push(Routes.character(ch.id));
    case _CharAction.edit:
      context.push(Routes.characterEdit(ch.id));
    case _CharAction.archive:
      final to = !ch.archived;
      await notifier.setArchived(ch.id, to);
      if (context.mounted) {
        showToast(
          context,
          to ? '${ch.first} archived' : '${ch.first} restored',
          onUndo: () => notifier.setArchived(ch.id, !to),
        );
      }
    case _CharAction.delete:
      final n = chats.length;
      final ok = await showConfirmDeleteSheet(
        context,
        title: 'Delete ${ch.name}?',
        message: n == 0
            ? 'The character and your relationship with them will be gone for good. Archive them instead if you might want them back.'
            : 'The character, your relationship with them and $n ${n == 1 ? 'chat' : 'chats'} will be gone for good. Archive them instead if you might want them back.',
        keepLabel: 'Keep ${ch.first}',
        deleteLabel: 'Delete',
      );
      if (!ok || !context.mounted) return;
      try {
        await notifier.delete(ch.id);
        if (context.mounted) showToast(context, '${ch.first} deleted');
      } catch (_) {
        if (context.mounted) {
          showToast(
            context,
            'Couldn’t delete. Check your connection and try again.',
          );
        }
      }
  }
}
