import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/toast.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/domain/chat_models.dart';
import '../../library/data/library_repository.dart';
import '../../library/data/sample_seed.dart';
import '../data/ai_prefs.dart';
import '../data/app_prefs.dart';
import '../data/model_usage.dart';
import '../data/profile_prefs.dart';
import '../data/reading_prefs.dart';

/// Text-size choices in Settings (the reading sheet allows any size 14–22).
final _sizeChoices = {
  15.0: 'Small',
  16.0: 'Default',
  18.0: 'Large',
  20.0: 'Larger',
};

/// Settings: account, theme and text size, new-chat mode, AI settings link,
/// privacy toggles and data.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final t = context.ht;
    final theme = ref.watch(themeChoiceProvider);
    final reading = ref.watch(readingPrefsProvider);
    final app = ref.watch(appPrefsProvider);
    final ai = ref.watch(aiPrefsProvider);
    final model = ref.watch(selectedModelProvider);
    final personas = ref.watch(personasProvider).valueOrNull ?? const [];
    final personaId = ref.watch(activePersonaIdProvider);
    final persona = personas.where((p) => p.id == personaId).firstOrNull;
    final online = ref.watch(usesBackendProvider);
    final email = ref.watch(authUserProvider)?.email;
    final mature = ref.watch(matureContentProvider).valueOrNull ?? false;

    // The nearest size choice is highlighted (the reading sheet allows others).
    final nearest = _sizeChoices.keys.reduce(
      (a, b) =>
          (a - reading.chatSize).abs() <= (b - reading.chatSize).abs() ? a : b,
    );

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

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm, top: Space.xs),
      child: Text(text, style: t.label.copyWith(fontSize: 15)),
    );

    Widget linkCard({
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) => Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card - 2),
        side: BorderSide(color: c.outline),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card - 2),
        ),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Hit.primary + Space.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.label.copyWith(fontSize: 15)),
                      Text(
                        subtitle,
                        style: t.caption.copyWith(color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textSubtle),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
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
                      'Settings',
                      style: t.display.copyWith(fontSize: 26),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.xxl,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(Space.lg),
                    margin: const EdgeInsets.only(bottom: Space.xl),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: Hit.primary + Space.xs,
                          height: Hit.primary + Space.xs,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            persona?.initial ?? '–',
                            textScaler: TextScaler.noScaling,
                            style: t.label.copyWith(
                              fontSize: 20,
                              color: c.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.lg - 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(persona?.name ?? 'You', style: t.label),
                              Text(
                                online
                                    ? (email == null || email.isEmpty
                                          ? 'Your stories are saved to your account'
                                          : email)
                                    : 'Your stories are saved on this device',
                                overflow: TextOverflow.ellipsis,
                                style: t.body.copyWith(color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  section('Appearance', [
                    label('Theme'),
                    HearthSegmented<HearthThemeChoice>(
                      semanticLabel: 'Theme',
                      options: {
                        for (final o in HearthThemeChoice.values) o: o.label,
                      },
                      value: theme,
                      onChanged: ref.read(themeChoiceProvider.notifier).set,
                    ),
                    const SizedBox(height: Space.md),
                    label('App text size'),
                    HearthSegmented<double>(
                      semanticLabel: 'App text size',
                      options: {
                        0.9: 'Smaller',
                        1.0: 'Normal',
                        1.15: 'Bigger',
                        1.3: 'Biggest',
                      },
                      value: app.uiScale,
                      onChanged: ref.read(appPrefsProvider.notifier).setUiScale,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Makes everything in the app bigger or smaller.',
                      style: t.caption.copyWith(color: c.textMuted),
                    ),
                    const SizedBox(height: Space.md),
                    label('Chat text size'),
                    HearthSegmented<double>(
                      semanticLabel: 'Chat text size',
                      options: _sizeChoices,
                      value: nearest,
                      onChanged: ref
                          .read(readingPrefsProvider.notifier)
                          .setChatSize,
                    ),
                  ]),
                  section('Roleplay', [
                    label('New chats open in'),
                    HearthSegmented<ChatMode>(
                      semanticLabel: 'Default roleplay mode',
                      options: const {
                        ChatMode.chat: 'Chat mode',
                        ChatMode.story: 'Story mode',
                      },
                      value: app.defaultMode,
                      onChanged: ref
                          .read(appPrefsProvider.notifier)
                          .setDefaultMode,
                    ),
                    const SizedBox(height: Space.md),
                    linkCard(
                      title: 'AI settings',
                      subtitle:
                          '${model.name} · ${ai.length.label} replies · ${ai.creativity.label}',
                      onTap: () => context.push(Routes.aiSettings),
                    ),
                    if (online) ...[
                      const SizedBox(height: Space.sm),
                      SwitchRow(
                        title: 'Mature content',
                        subtitle:
                            'Allow romance and adult themes between adult characters. '
                            'Everyone in a story is always an adult.',
                        value: mature,
                        onChanged: (v) async {
                          try {
                            await ref
                                .read(matureContentProvider.notifier)
                                .set(v);
                            if (context.mounted) {
                              showToast(
                                context,
                                v
                                    ? 'Mature content is on'
                                    : 'Mature content is off',
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              showToast(
                                context,
                                'Couldn’t save that. Check your connection.',
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ]),
                  section('Privacy', [
                    SwitchRow(
                      title: 'Hide message previews',
                      subtitle: 'Notifications say “New reply” instead of showing text.',
                      value: app.hidePreviews,
                      onChanged: ref
                          .read(appPrefsProvider.notifier)
                          .setHidePreviews,
                    ),
                    SwitchRow(
                      title: 'Blur in app switcher',
                      subtitle: 'Covers your chats when you switch apps.',
                      value: app.blurSwitcher,
                      onChanged: ref
                          .read(appPrefsProvider.notifier)
                          .setBlurSwitcher,
                    ),
                  ]),
                  section('Your data', [
                    linkCard(
                      title: 'Export everything',
                      subtitle: 'Characters, chats, universes and memories as one file',
                      onTap: () => showToast(
                        context,
                        'Export arrives with your online account, in a later update.',
                      ),
                    ),
                    if (online) ...[
                      const SizedBox(height: Space.sm),
                      linkCard(
                        title: ref.watch(seedingProvider)
                            ? 'Adding the sample stories…'
                            : 'Add the sample stories',
                        subtitle: 'Four characters and two worlds to try. Yours to edit or delete.',
                        onTap: () async {
                          try {
                            await seedSampleStories(ref);
                            if (context.mounted) {
                              showToast(context, 'Sample stories added');
                            }
                          } catch (_) {
                            if (context.mounted) {
                              showToast(
                                context,
                                'Couldn’t add them. Check your connection.',
                              );
                            }
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: Space.sm),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: c.danger,
                        alignment: AlignmentDirectional.centerStart,
                        minimumSize: const Size.fromHeight(Hit.primary),
                      ),
                      onPressed: () {
                        final auth = ref.read(authServiceProvider);
                        if (auth == null) {
                          showToast(
                            context,
                            'You’re not signed in: your stories are saved on this device.',
                          );
                        } else {
                          auth.signOut();
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                    Text(
                      'Hearth · v1.0',
                      style: t.caption.copyWith(fontSize: 12),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
