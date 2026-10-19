import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import '../util/roleplay_parser.dart';
import 'motion_widgets.dart';

/// Renders roleplay prose: *actions* italic and muted, "dialogue" brightest,
/// narration in between. Safe to rebuild on every streamed chunk.
class RichRoleplayText extends StatelessWidget {
  const RichRoleplayText(
    this.text, {
    super.key,
    required this.style,
    this.streaming = false,
    this.paragraphSpacing,
  });

  final String text;

  /// Base style: `context.ht.chatStyle(...)` or `context.ht.storyStyle(...)`.
  final TextStyle style;

  /// Shows a blinking caret after the last character.
  final bool streaming;

  /// Defaults to half a line of [style].
  final double? paragraphSpacing;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final paragraphs = parseRoleplay(text);
    final gap =
        paragraphSpacing ?? (style.fontSize ?? Reading.chatSize.def) * 0.6;

    TextStyle styleFor(RoleKind k) => switch (k) {
      RoleKind.action => style.copyWith(
        fontStyle: FontStyle.italic,
        color: c.textMuted,
      ),
      RoleKind.dialogue => style.copyWith(color: c.dialogue),
      RoleKind.narration => style.copyWith(color: c.narration),
    };

    if (paragraphs.isEmpty) {
      return streaming
          ? Text.rich(TextSpan(children: [_caret(c.primaryInk)]), style: style)
          : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Text.rich(
            TextSpan(
              style: style,
              children: [
                for (final s in paragraphs[i])
                  TextSpan(text: s.text, style: styleFor(s.kind)),
                if (streaming && i == paragraphs.length - 1)
                  _caret(c.primaryInk),
              ],
            ),
          ),
        ],
      ],
    );
  }

  InlineSpan _caret(Color color) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: _Caret(
      color: color,
      height: (style.fontSize ?? Reading.chatSize.def),
    ),
  );
}

class _Caret extends StatefulWidget {
  const _Caret({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 0.25, end: 1.0).animate(_c),
        child: Container(
          width: Space.xs / 2,
          height: widget.height,
          margin: const EdgeInsets.only(left: Space.xs / 2),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(Space.xs / 4),
          ),
        ),
      ),
    );
  }
}
