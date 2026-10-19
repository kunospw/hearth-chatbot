import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/refresh.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import 'memories_view.dart';
import 'personas_view.dart';
import 'universes_view.dart';

enum LibrarySection {
  universes('Universes'),
  memories('Memories'),
  personas('Personas');

  const LibrarySection(this.label);
  final String label;

  static LibrarySection fromQuery(String? q) =>
      LibrarySection.values.asNameMap()[q] ?? LibrarySection.universes;
}

/// Universes, Memories and Personas behind a segmented control. `?tab=` picks
/// the section (universes, memories or personas).
class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key, this.tab});

  final String? tab;

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  late LibrarySection _section = LibrarySection.fromQuery(widget.tab);

  @override
  void didUpdateWidget(LibraryTab old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _section = LibrarySection.fromQuery(widget.tab);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The header may scroll on its own at very large text sizes, so it
            // can never push the page off the bottom.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.xl,
                  Space.gutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Library', style: t.display),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Your worlds, the things they remember, and who you play as.',
                      style: t.body.copyWith(color: context.hc.textMuted),
                    ),
                    const SizedBox(height: Space.md + 2),
                    HearthSegmented<LibrarySection>(
                      semanticLabel: 'Library sections',
                      options: {
                        for (final s in LibrarySection.values) s: s.label,
                      },
                      value: _section,
                      onChanged: (s) => setState(() => _section = s),
                    ),
                  ],
                ),
              ),
            ),
            const LoadingBar(),
            Expanded(
              child: switch (_section) {
                LibrarySection.universes => const UniversesView(),
                LibrarySection.memories => const MemoriesView(),
                LibrarySection.personas => const PersonasView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
