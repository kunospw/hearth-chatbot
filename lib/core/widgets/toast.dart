import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

/// Light pill toast with an optional Undo. It floats above the bottom bar and
/// is the only place (with the new-reply pill) that carries a shadow.
/// Shows for 4s, or 6s when there's an Undo, and replaces any toast on screen.
///
/// Screens with a bar pinned to the bottom (the chat composer, the editor's
/// Save button) wrap it in [ToastInset], so toasts float above it instead of
/// covering it. Pass [aboveBottomBar] false for a toast shown as the screen
/// closes.
void showToast(
  BuildContext context,
  String text, {
  VoidCallback? onUndo,
  bool aboveBottomBar = true,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final c = context.hc;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: Duration(seconds: onUndo == null ? 4 : 6),
      backgroundColor: c.text,
      elevation: Space.sm,
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.xs,
        Space.xs,
        Space.xs,
      ),
      margin: EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        Space.lg + (aboveBottomBar ? ToastInsets.current : 0),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Hit.primary + Space.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: context.ht.body.copyWith(
                  color: c.onInverse,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onUndo != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: c.inverseAccent,
                  minimumSize: const Size(Hit.inline, Hit.inline),
                ),
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onUndo();
                },
                child: Text(
                  'Undo',
                  style: context.ht.label.copyWith(
                    color: c.inverseAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Heights of bars pinned to the bottom of the screens currently open. The
/// newest (top-most) screen wins.
abstract final class ToastInsets {
  static final Map<Object, double> _heights = {};

  static double get current => _heights.isEmpty ? 0 : _heights.values.last;

  static void _set(Object key, double h) {
    _heights.remove(key); // re-insert so the most recent registration is last
    _heights[key] = h;
  }

  static void _clear(Object key) => _heights.remove(key);
}

/// Wrap a bottom-pinned bar so toasts appear above it. Measures the bar's
/// height (including the safe area) and keeps it up to date.
class ToastInset extends StatefulWidget {
  const ToastInset({super.key, required this.child});

  final Widget child;

  @override
  State<ToastInset> createState() => _ToastInsetState();
}

class _ToastInsetState extends State<ToastInset> {
  final Object _token = Object();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      ToastInsets._set(_token, box.size.height);
    }
  }

  @override
  void dispose() {
    ToastInsets._clear(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}
