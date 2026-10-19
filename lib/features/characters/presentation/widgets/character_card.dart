import 'package:flutter/material.dart';

import '../../../../core/theme/hearth_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/character_avatar.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../domain/character.dart';

/// Grid card: portrait, name, two-line description and the first tag.
/// One InkWell; at least 210dp tall but grows with text size.
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.onTap,
    this.onMore,
    this.index = 0,
  });

  final Character character;
  final VoidCallback onTap;

  /// Shows a ⋯ button on the portrait when set (archive, delete…).
  final VoidCallback? onMore;
  final int index;

  static const double minHeight = 210;

  /// Portrait width : height.
  static const double portraitAspect = 1.6;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final ch = character;
    return EntranceFade(
      index: index,
      child: PressScale(
        child: Semantics(
          button: true,
          label: '${ch.name}. ${ch.short}',
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: portraitAspect,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CharacterAvatar.of(
                            ch,
                            size: double.infinity,
                            height: double.infinity,
                            radius: 0,
                            initialSize: Space.xxl * 2,
                          ),
                          if (onMore != null)
                            Positioned(
                              top: Space.xs,
                              right: Space.xs,
                              child: Material(
                                color: c.scrim,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'More options for ${ch.first}',
                                  constraints: const BoxConstraints(
                                    minWidth: Hit.inline,
                                    minHeight: Hit.inline,
                                  ),
                                  icon: Icon(
                                    Icons.more_horiz,
                                    color: c.onScrim,
                                  ),
                                  onPressed: onMore,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(Space.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.ht.title,
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            ch.short,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.ht.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                          if (ch.tags.isNotEmpty) ...[
                            const SizedBox(height: Space.sm),
                            // The character's own tile/ink pair keeps the tag readable
                            // on both light and dark cards.
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.sm,
                                  vertical: Space.xs / 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ch.tile,
                                  borderRadius: BorderRadius.circular(
                                    Radii.field,
                                  ),
                                ),
                                child: Text(
                                  ch.tags.first,
                                  style: context.ht.caption.copyWith(
                                    color: ch.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dashed "Create a character" card that ends the grid.
class CreateCharacterCard extends StatelessWidget {
  const CreateCharacterCard({super.key, required this.onTap, this.index = 0});

  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return EntranceFade(
      index: index,
      child: PressScale(
        child: Semantics(
          button: true,
          label: 'Create a character',
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
              side: BorderSide(color: c.outline, width: Sizes.stroke),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CharacterCard.minHeight,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: Space.xxl,
                          color: c.primaryInk,
                        ),
                        const SizedBox(height: Space.sm),
                        Text(
                          'Create a character',
                          textAlign: TextAlign.center,
                          style: context.ht.label.copyWith(color: c.primaryInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
