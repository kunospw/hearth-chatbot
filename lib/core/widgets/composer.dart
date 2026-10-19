import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

enum ComposerVariant { chat, story }

/// Message composer: 1–5 lines, Send ↔ Stop, bottom SafeArea.
///
/// - Enter inserts a newline; Ctrl/Cmd+Enter sends (hardware keyboards).
/// - Story variant: hint "What happens next? (optional)" and sending empty
///   means *Continue*, so [onSend] may receive an empty string.
/// - While [isGenerating], the button is Stop and sending is disabled.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    this.onStop,
    this.isGenerating = false,
    this.variant = ComposerVariant.chat,
    this.controller,
    this.focusNode,
    this.hintText,
  });

  /// Called with the trimmed text; the composer clears itself afterwards.
  final ValueChanged<String> onSend;
  final VoidCallback? onStop;
  final bool isGenerating;
  final ComposerVariant variant;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;

  static const int maxLines = 5;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  late final TextEditingController _own = TextEditingController();
  TextEditingController get _c => widget.controller ?? _own;

  bool get _story => widget.variant == ComposerVariant.story;
  bool get _hasText => _c.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onText);
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own).removeListener(_onText);
      _c.addListener(_onText);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onText);
    _own.dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  void _send() {
    if (widget.isGenerating) return;
    if (!_story && !_hasText) return;
    final text = _c.text.trim();
    _c.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final hint =
        widget.hintText ??
        (_story ? 'What happens next? (optional)' : 'Message');

    return Material(
      color: c.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(
                      LogicalKeyboardKey.enter,
                      control: true,
                    ): _send,
                    const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                        _send,
                  },
                  child: TextField(
                    controller: _c,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: Composer.maxLines,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.ht.chat,
                    decoration: InputDecoration(
                      hintText: hint,
                      filled: true,
                      fillColor: c.surface,
                      constraints: const BoxConstraints(minHeight: Hit.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              _action(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context) {
    final c = context.hc;
    if (widget.isGenerating) {
      return _RoundButton(
        key: const ValueKey('stop'),
        tooltip: 'Stop reply',
        icon: Icons.stop_rounded,
        onPressed: widget.onStop,
        background: c.primary,
        foreground: c.onPrimary,
      );
    }
    if (_story) {
      // Labelled pill: "Continue" when empty, "Send" when there's text.
      final label = _hasText ? 'Send' : 'Continue';
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: _send,
        child: FilledButton(
          key: const ValueKey('story-send'),
          onPressed: _send,
          child: AnimatedSwitcher(
            duration: Motion.press,
            child: Text(label, key: ValueKey(label)),
          ),
        ),
      );
    }
    final enabled = _hasText;
    return _RoundButton(
      key: const ValueKey('send'),
      tooltip: 'Send message',
      icon: Icons.arrow_upward_rounded,
      onPressed: enabled ? _send : null,
      background: enabled ? c.primary : c.surfaceRaised,
      foreground: enabled ? c.onPrimary : c.textSubtle,
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.background,
    required this.foreground,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.press,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(Hit.primary),
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
        ),
        icon: AnimatedSwitcher(
          duration: Motion.press,
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(icon, key: ValueKey(icon)),
        ),
      ),
    );
  }
}
