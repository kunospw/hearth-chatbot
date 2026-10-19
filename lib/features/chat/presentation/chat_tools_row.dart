import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/toast.dart';
import '../../library/data/library_repository.dart';
import '../data/chat_controller.dart';
import '../data/conversation_repository.dart';
import '../data/suggestions_controller.dart';

/// Switches who you play as in this chat (and in the relationship journal, which
/// follows the persona). Also makes the chat remember it, on every device.
Future<void> showPersonaSwitcher(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  final personas = ref.read(personasProvider).valueOrNull ?? const [];
  final conv = ref.read(conversationProvider(conversationId));
  final current = conv?.personaId ?? ref.read(activePersonaIdProvider);
  final choice = await showOptionsSheet<String>(
    context,
    title: 'Play this chat as',
    options: [
      for (final p in personas)
        SheetOption(
          value: p.id,
          label: p.name,
          icon: p.id == current
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          meta: p.id == current ? 'Now' : null,
        ),
    ],
  );
  if (choice == null || choice == current || !context.mounted) return;
  ref.read(selectedPersonaIdProvider.notifier).select(choice);
  ref.read(conversationsProvider.notifier).setPersona(conversationId, choice);
  final name =
      personas.where((p) => p.id == choice).firstOrNull?.name ?? 'them';
  // Ideas written for the old persona no longer fit.
  ref.read(suggestionsProvider(conversationId).notifier).clear();
  showToast(context, 'Now playing as $name');
}

/// A slim row above the composer: who you are in this chat, and a button that
/// suggests things you could say. Picking a suggestion puts it in the message
/// box for you to change and send; nothing is sent for you.
class ChatToolsRow extends ConsumerWidget {
  const ChatToolsRow({
    super.key,
    required this.conversationId,
    required this.onPick,
  });

  final String conversationId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final t = context.ht;
    final busy = ref.watch(chatControllerProvider(conversationId)).busy;
    final conv = ref.watch(conversationProvider(conversationId));
    final personas = ref.watch(personasProvider).valueOrNull ?? const [];
    final active = ref.watch(activePersonaIdProvider);
    final s = ref.watch(suggestionsProvider(conversationId));
    if (conv == null) return const SizedBox.shrink();

    final currentId = conv.personaId ?? active;
    final persona = personas.where((p) => p.id == currentId).firstOrNull;
    // Ideas only fit the moment they were written for.
    final fresh = !busy && s.forMessageId == conv.last?.id;
    final loading = s.status == SuggestStatus.loading && fresh;
    final ready = s.status == SuggestStatus.ready && fresh;
    final failed = s.status == SuggestStatus.failed && fresh;
    final lastIsTheirs = conv.last != null && !conv.last!.isUser;

    // The row keeps its height while a reply is written (its buttons just go
    // quiet), so nothing on the page moves under someone who is reading.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: Hit.primary,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.sm, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!busy && personas.length > 1 && persona != null)
                  Flexible(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(Hit.inline, Hit.inline),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                        ),
                      ),
                      onPressed: () =>
                          showPersonaSwitcher(context, ref, conversationId),
                      icon: const Icon(
                        Icons.person_outline,
                        size: Space.xl - Space.xs,
                      ),
                      label: Text(
                        'As ${persona.name}',
                        overflow: TextOverflow.ellipsis,
                        style: t.label.copyWith(color: c.textMuted),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (!busy && lastIsTheirs)
                  Flexible(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(Hit.inline, Hit.inline),
                      ),
                      onPressed: loading
                          ? null
                          : () => ref
                                .read(
                                  suggestionsProvider(conversationId).notifier,
                                )
                                .fetch(),
                      icon: loading
                          ? const SizedBox.square(
                              dimension: Space.lg,
                              child: CircularProgressIndicator(
                                strokeWidth: Sizes.stroke,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome,
                              size: Space.xl - Space.xs,
                            ),
                      label: Text(
                        loading
                            ? 'Thinking of ideas…'
                            : (ready ? 'New ideas' : 'Suggest replies'),
                        overflow: TextOverflow.ellipsis,
                        style: t.label,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.sm,
            ),
            child: Text(
              s.error ?? 'Couldn’t come up with ideas.',
              style: t.caption.copyWith(color: c.danger),
            ),
          ),
        if (ready)
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.sm,
              ),
              itemCount: s.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (context, i) => SizedBox(
                width: 250,
                child: Semantics(
                  button: true,
                  label: 'Use this reply: ${s.items[i]}',
                  excludeSemantics: true,
                  onTap: () {
                    onPick(s.items[i]);
                    ref
                        .read(suggestionsProvider(conversationId).notifier)
                        .clear();
                  },
                  child: Material(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.card),
                      onTap: () {
                        onPick(s.items[i]);
                        ref
                            .read(suggestionsProvider(conversationId).notifier)
                            .clear();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(Space.md),
                        child: Text(
                          s.items[i],
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: t.body,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
