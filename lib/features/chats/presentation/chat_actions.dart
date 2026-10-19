import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/toast.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/chat_models.dart';

enum _ChatAction { pin, rename, archive, delete }

/// The ⋯ menu of a chat: pin, rename, archive and delete. Used by the Chats
/// list, the home screen and a character's page, so they all offer the same
/// things. [onDeleted] runs after a delete (a wide layout closes its pane).
Future<void> showChatOptions(
  BuildContext context,
  WidgetRef ref,
  Conversation c, {
  VoidCallback? onDeleted,
}) async {
  final choice = await showOptionsSheet<_ChatAction>(
    context,
    title: c.title,
    options: [
      if (!c.archived)
        SheetOption(
          value: _ChatAction.pin,
          label: c.pinned ? 'Unpin' : 'Pin to top',
          icon: c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
        ),
      const SheetOption(
        value: _ChatAction.rename,
        label: 'Rename',
        icon: Icons.edit_outlined,
      ),
      SheetOption(
        value: _ChatAction.archive,
        label: c.archived ? 'Unarchive' : 'Archive',
        icon: c.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
      ),
      const SheetOption(
        value: _ChatAction.delete,
        label: 'Delete chat…',
        icon: Icons.delete_outline,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted || choice == null) return;
  final notifier = ref.read(conversationsProvider.notifier);
  switch (choice) {
    case _ChatAction.pin:
      notifier.togglePin(c.id);
      showToast(context, c.pinned ? 'Unpinned' : 'Pinned to top');
    case _ChatAction.rename:
      final name = await showTextInputSheet(
        context,
        title: 'Rename chat',
        initial: c.title,
        confirmLabel: 'Save',
      );
      if (!context.mounted || name == null) return;
      notifier.rename(c.id, name);
      showToast(context, 'Renamed');
    case _ChatAction.archive:
      final to = !c.archived;
      notifier.setArchived(c.id, to);
      showToast(
        context,
        to ? 'Chat archived' : 'Chat restored',
        onUndo: () => notifier.setArchived(c.id, !to),
      );
    case _ChatAction.delete:
      final ok = await showConfirmDeleteSheet(
        context,
        title: 'Delete “${c.title}”?',
        message:
            'The conversation will be gone for good. '
            'Memories saved to the universe stay safe. '
            'Archive it instead if you might want it back.',
        keepLabel: 'Keep it',
        deleteLabel: 'Delete',
      );
      if (!ok || !context.mounted) return;
      await notifier.delete(c.id);
      onDeleted?.call();
      if (context.mounted) showToast(context, 'Chat deleted');
  }
}
