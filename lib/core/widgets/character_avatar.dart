import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/characters/domain/character.dart';
import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import 'motion_widgets.dart';

enum AvatarShape { circle, rounded }

/// Character picture. Paints the character's tile colour and initial first,
/// fades the image in over 150ms, and keeps the initial if the image fails.
/// The app accent never sits behind a portrait.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.tile,
    required this.ink,
    required this.initial,
    this.asset,
    this.url,
    this.bytes,
    this.size = Sizes.avatar,
    this.height,
    this.shape = AvatarShape.rounded,
    this.radius = Radii.field,
    this.initialSize,
  });

  CharacterAvatar.of(
    Character c, {
    Key? key,
    double size = Sizes.avatar,
    double? height,
    AvatarShape shape = AvatarShape.rounded,
    double radius = Radii.field,
    double? initialSize,
  }) : this(
         key: key,
         tile: c.tile,
         ink: c.ink,
         initial: c.initial,
         asset: c.portraitAsset,
         url: c.portraitUrl,
         bytes: c.portraitBytes,
         size: size,
         height: height,
         shape: shape,
         radius: radius,
         initialSize: initialSize,
       );

  final Color tile;
  final Color ink;
  final String initial;

  /// Bundled SVG portrait. Preferred over [url].
  final String? asset;
  final String? url;

  /// A picture chosen on this device.
  final Uint8List? bytes;

  /// Width (and height unless [height] is given).
  final double size;
  final double? height;
  final AvatarShape shape;
  final double radius;

  /// Font size of the initial. Defaults to 42% of the smaller side; set it
  /// when [size] is `double.infinity` (fills a tight parent, e.g. AspectRatio).
  final double? initialSize;

  static const _fade = Duration(milliseconds: 150);
  static const _fullyRound = 9999.0;

  @override
  Widget build(BuildContext context) {
    final h = height ?? size;
    final fade = reduceMotion(context) ? Duration.zero : _fade;
    final r = shape == AvatarShape.circle
        ? const BorderRadius.all(Radius.circular(_fullyRound))
        : BorderRadius.circular(radius);

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: h,
        child: ClipRRect(
          borderRadius: r,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: tile),
              Center(
                child: Text(
                  initial,
                  textScaler: TextScaler.noScaling,
                  style: context.ht.title.copyWith(
                    color: ink,
                    fontSize: initialSize ?? (size < h ? size : h) * 0.42,
                    height: 1,
                  ),
                ),
              ),
              if (bytes != null)
                _FadeIn(
                  duration: fade,
                  child: Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                )
              else if (asset != null)
                _FadeIn(
                  duration: fade,
                  child: SvgPicture.asset(
                    asset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                )
              else if (url != null)
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  fadeInDuration: fade,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (_, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}
