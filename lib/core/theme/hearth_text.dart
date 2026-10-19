import 'package:flutter/material.dart';

import 'hearth_colors.dart';
import 'tokens.dart';

/// Newsreader = story and display serif; Figtree = UI (SPEC §2).
/// Both families are bundled as variable fonts (see pubspec), so the weight is
/// also set on the `wght` axis explicitly.
abstract final class HearthFonts {
  static const String serif = 'Newsreader';
  static const String sans = 'Figtree';
}

TextStyle _style({
  required String family,
  required double size,
  required double height,
  required int weight,
  required Color color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
    color: color,
    letterSpacing: letterSpacing,
  );
}

/// Role-based text styles. `story` and `chat` are the user-adjustable ones;
/// use [storyStyle] / [chatStyle] with the reading preferences.
@immutable
class HearthText extends ThemeExtension<HearthText> {
  const HearthText({
    required this.display,
    required this.title,
    required this.story,
    required this.chat,
    required this.label,
    required this.body,
    required this.overline,
    required this.caption,
  });

  final TextStyle display;
  final TextStyle title;
  final TextStyle story;
  final TextStyle chat;
  final TextStyle label;
  final TextStyle body;
  final TextStyle overline;
  final TextStyle caption;

  factory HearthText.from(HearthColors c) {
    return HearthText(
      display: _style(
        family: HearthFonts.serif,
        size: 30,
        height: 1.15,
        weight: 500,
        color: c.text,
      ),
      title: _style(
        family: HearthFonts.serif,
        size: 19,
        height: 1.25,
        weight: 500,
        color: c.text,
      ),
      story: _style(
        family: HearthFonts.serif,
        size: Reading.storySize.def,
        height: Reading.storyLineHeights[1],
        weight: 400,
        color: c.narration,
      ),
      chat: _style(
        family: HearthFonts.sans,
        size: Reading.chatSize.def,
        height: Reading.chatLineHeights[1],
        weight: 400,
        color: c.text,
      ),
      label: _style(
        family: HearthFonts.sans,
        size: 16,
        height: 1.25,
        weight: 600,
        color: c.text,
      ),
      body: _style(
        family: HearthFonts.sans,
        size: 15,
        height: 1.5,
        weight: 400,
        color: c.text,
      ),
      overline: _style(
        family: HearthFonts.sans,
        size: 13,
        height: 1.3,
        weight: 600,
        color: c.textSubtle,
        letterSpacing: 13 * 0.06,
      ),
      caption: _style(
        family: HearthFonts.sans,
        size: 13,
        height: 1.45,
        weight: 400,
        color: c.textSubtle,
      ),
    );
  }

  /// Story prose at a user-chosen size and line height (15–26 / 1.58–1.90).
  TextStyle storyStyle({double? size, double? lineHeight}) {
    return story.copyWith(
      fontSize: (size ?? Reading.storySize.def).clamp(
        Reading.storySize.min,
        Reading.storySize.max,
      ),
      height: lineHeight ?? Reading.storyLineHeights[1],
    );
  }

  /// Chat text at a user-chosen size and line height (14–22 / 1.50–1.80).
  TextStyle chatStyle({double? size, double? lineHeight}) {
    return chat.copyWith(
      fontSize: (size ?? Reading.chatSize.def).clamp(
        Reading.chatSize.min,
        Reading.chatSize.max,
      ),
      height: lineHeight ?? Reading.chatLineHeights[1],
    );
  }

  @override
  HearthText copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? story,
    TextStyle? chat,
    TextStyle? label,
    TextStyle? body,
    TextStyle? overline,
    TextStyle? caption,
  }) {
    return HearthText(
      display: display ?? this.display,
      title: title ?? this.title,
      story: story ?? this.story,
      chat: chat ?? this.chat,
      label: label ?? this.label,
      body: body ?? this.body,
      overline: overline ?? this.overline,
      caption: caption ?? this.caption,
    );
  }

  @override
  HearthText lerp(ThemeExtension<HearthText>? other, double t) {
    if (other is! HearthText) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return HearthText(
      display: l(display, other.display),
      title: l(title, other.title),
      story: l(story, other.story),
      chat: l(chat, other.chat),
      label: l(label, other.label),
      body: l(body, other.body),
      overline: l(overline, other.overline),
      caption: l(caption, other.caption),
    );
  }
}
