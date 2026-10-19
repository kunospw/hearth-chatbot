import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/characters/presentation/character_details_screen.dart';
import '../../features/characters/presentation/character_editor_screen.dart';
import '../../features/characters/presentation/characters_tab.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chats/presentation/chats_tab.dart';
import '../../features/dev/presentation/dev_screen.dart';
import '../../features/dev/presentation/gallery_screen.dart';
import '../../features/library/presentation/library_tab.dart';
import '../../features/settings/presentation/ai_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/library/presentation/universe_screens.dart';
import 'app_shell.dart';
import 'routes.dart';
import '../../features/relationship/presentation/relationship_journal_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  // Detail screens are full screen with no bottom bar, so they hang off the
  // root navigator (parentNavigatorKey) rather than the shell.
  GoRoute full(
    String path,
    Widget Function(GoRouterState s) build, {
    bool fullscreenDialog = false,
  }) {
    return GoRoute(
      path: path,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: fullscreenDialog,
        child: build(state),
      ),
    );
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.characters,
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            FadeBranches(currentIndex: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.characters,
                builder: (context, state) => const CharactersTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.chats,
                builder: (context, state) => const ChatsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) =>
                    LibraryTab(tab: state.uri.queryParameters['tab']),
              ),
            ],
          ),
        ],
      ),
      // `new` must be declared before `:id`.
      full(
        Routes.characterNew,
        (s) => CharacterEditorScreen(
          draftId: s.uri.queryParameters['draft'],
          initialName: s.uri.queryParameters['name'],
        ),
        fullscreenDialog: true,
      ),
      full(
        '/characters/:id',
        (s) => CharacterDetailsScreen(characterId: s.pathParameters['id']!),
      ),
      full(
        '/characters/:id/edit',
        (s) => CharacterEditorScreen(
          characterId: s.pathParameters['id'],
          draftId: s.uri.queryParameters['draft'],
        ),
        fullscreenDialog: true,
      ),
      full(
        '/characters/:id/relationship',
        (s) => RelationshipJournalScreen(
          characterId: s.pathParameters['id']!,
          entryId: s.uri.queryParameters['entry'],
        ),
      ),
      full(
        '/chat/:conversationId',
        (s) => ChatScreen(conversationId: s.pathParameters['conversationId']!),
      ),
      full(
        '/universes/:id',
        (s) => UniverseDetailScreen(universeId: s.pathParameters['id']!),
      ),
      full(
        '/universes/:id/memories',
        (s) => UniverseMemoriesScreen(universeId: s.pathParameters['id']!),
      ),
      full(Routes.settings, (s) => const SettingsScreen()),
      full(Routes.aiSettings, (s) => const AiSettingsScreen()),
      if (kDebugMode) full(Routes.dev, (s) => const DevScreen()),
      if (kDebugMode) full(Routes.devGallery, (s) => const GalleryScreen()),
    ],
  );
});
