import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/characters/data/character_repository.dart';
import '../../features/chat/data/conversation_repository.dart';
import '../../features/library/data/library_repository.dart';
import '../../features/relationship/data/relationship_providers.dart';
import '../../features/settings/data/model_repository.dart';
import '../backend/backend_providers.dart';
import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import 'toast.dart';

/// Reloads everything the app shows from the server (or the sample data):
/// characters, chats, library, models and open relationships. Anything you
/// changed that is still waiting to be saved is saved first, so a refresh never
/// throws your latest messages away.
Future<void> refreshAll(WidgetRef ref) async {
  final convs = ref.read(conversationsProvider.notifier);
  for (final c in ref.read(conversationsProvider).valueOrNull ?? const []) {
    try {
      await convs.flush(c.id);
    } catch (_) {
      // Offline: the refresh below fails too and says so.
    }
  }
  ref.invalidate(charactersProvider);
  ref.invalidate(conversationsProvider);
  ref.invalidate(universesProvider);
  ref.invalidate(memoriesProvider);
  ref.invalidate(personasProvider);
  ref.invalidate(modelsProvider);
  ref.invalidate(relationshipsProvider);
  final results = await Future.wait<Object?>([
    ref
        .read(charactersProvider.future)
        .then<Object?>((v) => v, onError: (Object e) => e),
    ref
        .read(conversationsProvider.future)
        .then<Object?>((v) => v, onError: (Object e) => e),
    ref
        .read(universesProvider.future)
        .then<Object?>((v) => v, onError: (Object e) => e),
    ref
        .read(memoriesProvider.future)
        .then<Object?>((v) => v, onError: (Object e) => e),
    ref
        .read(personasProvider.future)
        .then<Object?>((v) => v, onError: (Object e) => e),
  ]);
  if (results.any((r) => r is Exception || r is Error)) {
    throw const RefreshFailed();
  }
}

class RefreshFailed implements Exception {
  const RefreshFailed();
}

/// Pull down on a list to reload it. The child must be a scrollable.
class PullToRefresh extends ConsumerWidget {
  const PullToRefresh({super.key, required this.child, this.onRefresh});

  final Widget child;

  /// What to reload. Defaults to everything.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    return RefreshIndicator(
      color: c.primaryInk,
      backgroundColor: c.surfaceRaised,
      onRefresh: () async {
        try {
          await (onRefresh ?? () => refreshAll(ref))();
        } catch (_) {
          if (context.mounted) {
            showToast(context, 'Couldn’t refresh. Check your connection.');
          }
        }
      },
      child: child,
    );
  }
}

/// Scrolling that always lets you pull, even when the list is short.
const refreshablePhysics = AlwaysScrollableScrollPhysics();

/// A button for places where pulling is awkward (a mouse, a short page). Shows
/// a spinner while it works.
class RefreshButton extends ConsumerStatefulWidget {
  const RefreshButton({super.key, this.onRefresh});

  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<RefreshButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await (widget.onRefresh ?? () => refreshAll(ref))();
    } catch (_) {
      if (mounted) {
        showToast(context, 'Couldn’t refresh. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _busy ? 'Refreshing…' : 'Refresh',
      constraints: const BoxConstraints(
        minWidth: Hit.primary,
        minHeight: Hit.primary,
      ),
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox.square(
              dimension: Space.xl - Space.xs,
              child: CircularProgressIndicator(strokeWidth: Sizes.stroke),
            )
          : const Icon(Icons.refresh),
    );
  }
}

/// A thin bar under a header that moves while the app is loading something it
/// already has on screen (a refresh), so you can tell it is working.
class LoadingBar extends ConsumerWidget {
  const LoadingBar({super.key});

  static bool _reloading(AsyncValue<Object?> v) => v.isLoading && v.hasValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        _reloading(ref.watch(charactersProvider)) ||
        _reloading(ref.watch(conversationsProvider)) ||
        _reloading(ref.watch(universesProvider)) ||
        _reloading(ref.watch(memoriesProvider)) ||
        _reloading(ref.watch(personasProvider));
    return SizedBox(
      height: 3,
      child: active
          ? LinearProgressIndicator(
              minHeight: 3,
              color: context.hc.primaryInk,
              backgroundColor: Colors.transparent,
            )
          : null,
    );
  }
}

/// Reloads when the app comes back to the front (switching back to the browser
/// tab, or to the app on your phone), so a chat you continued on another
/// device is there when you return.
class RefreshOnResume extends ConsumerStatefulWidget {
  const RefreshOnResume({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends ConsumerState<RefreshOnResume> {
  late final AppLifecycleListener _listener;
  DateTime _last = DateTime.now();

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    // Only with a server, and not more than once every 20 seconds.
    if (!ref.read(usesBackendProvider)) return;
    if (DateTime.now().difference(_last) < const Duration(seconds: 20)) return;
    _last = DateTime.now();
    unawaited(refreshAll(ref).catchError((Object _) {}));
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
