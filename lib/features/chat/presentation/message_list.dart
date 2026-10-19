import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/motion_widgets.dart';

/// Where the reader was: the first visible message and how far (0–1) they had
/// scrolled into it, or "at the bottom". Captured before switching between Chat
/// and Story and restored afterwards so both land on the same spot.
@immutable
class ScrollAnchor {
  const ScrollAnchor.bottom() : messageId = null, fraction = 0, atBottom = true;
  const ScrollAnchor(String this.messageId, this.fraction) : atBottom = false;

  final String? messageId;
  final double fraction;
  final bool atBottom;

  @override
  String toString() => atBottom
      ? 'ScrollAnchor.bottom'
      : 'ScrollAnchor($messageId, ${fraction.toStringAsFixed(2)})';
}

/// One row of the list, oldest first. Only [isMessage] rows can be anchors.
class ListEntry {
  const ListEntry({
    required this.id,
    required this.builder,
    this.isMessage = true,
  });

  final String id;
  final bool isMessage;
  final WidgetBuilder builder;
}

/// The scrolling list used by both Chat (reversed, newest at the bottom with
/// offset 0) and Story (normal direction). Handles:
/// - following new text only within [Reading.followThreshold] of the bottom,
/// - capturing and restoring a [ScrollAnchor],
/// - reporting when the reader leaves or returns to the bottom.
class MessageList extends StatefulWidget {
  const MessageList({
    super.key,
    required this.entries,
    required this.reversed,
    this.initialAnchor,
    this.onNearBottomChanged,
    this.maxContentWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.lg),
    this.verticalPadding = Space.lg,
  });

  /// Oldest first.
  final List<ListEntry> entries;

  /// True for Chat: a reversed ListView so the bottom is offset 0.
  final bool reversed;

  /// Restored once after the first layout. Null on a fresh open: Chat starts at
  /// the bottom, Story jumps to the bottom (the newest message).
  final ScrollAnchor? initialAnchor;
  final ValueChanged<bool>? onNearBottomChanged;

  /// Centres content and caps its width (Story: 640dp).
  final double? maxContentWidth;
  final EdgeInsets padding;
  final double verticalPadding;

  @override
  State<MessageList> createState() => MessageListState();
}

class MessageListState extends State<MessageList> {
  final _keys = <String, GlobalKey>{};
  final _viewportKey = GlobalKey();
  final _controller = ScrollController();

  bool _ready = false;
  bool _near = true;
  int _passes = 0;
  int _attempts = 0;
  double _lastMax = -1;

  static const _maxAttempts = 12;

  ScrollController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    if (widget.initialAnchor == null && widget.reversed) {
      _ready = true;
    } else {
      _scheduleRestore(widget.initialAnchor ?? const ScrollAnchor.bottom());
    }
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final removed = _keys.keys.toSet()
      ..removeAll(widget.entries.map((e) => e.id));
    for (final id in removed) {
      _keys.remove(id);
    }
    // Content changed while the reader is at the bottom: stay at the bottom.
    if (_ready &&
        _near &&
        !listEquals(
          oldWidget.entries.map((e) => e.id).toList(),
          widget.entries.map((e) => e.id).toList(),
        )) {
      SchedulerBinding.instance.addPostFrameCallback((_) => jumpToBottom());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  // ── position ──────────────────────────────────────────────────────────

  bool get nearBottom {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return true;
    }
    final p = _controller.position;
    return widget.reversed
        ? p.pixels - p.minScrollExtent <= Reading.followThreshold
        : p.maxScrollExtent - p.pixels <= Reading.followThreshold;
  }

  void _onScroll() {
    if (!_ready) return;
    final n = nearBottom;
    if (n == _near) return;
    _near = n;
    final cb = widget.onNearBottomChanged;
    if (cb == null) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => cb(n));
    } else {
      cb(n);
    }
  }

  void jumpToBottom() {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return;
    }
    final p = _controller.position;
    final t = widget.reversed ? p.minScrollExtent : p.maxScrollExtent;
    if ((p.pixels - t).abs() > 0.5) _controller.jumpTo(t);
  }

  /// Scrolls to the newest message (used after the reader sends something).
  void scrollToBottom({bool animate = false}) {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return;
    }
    final p = _controller.position;
    final t = widget.reversed ? p.minScrollExtent : p.maxScrollExtent;
    if (!animate || reduceMotion(context)) {
      _controller.jumpTo(t);
      return;
    }
    _controller
        .animateTo(
          t,
          duration: Motion.sheet,
          curve: Motion.emphasizedDecelerate,
        )
        .then((_) {
          if (mounted && !widget.reversed) jumpToBottom();
        });
  }

  // ── anchor ────────────────────────────────────────────────────────────

  RenderBox? get _viewport =>
      _viewportKey.currentContext?.findRenderObject() as RenderBox?;

  RenderBox? _boxFor(String id) {
    final ro = _keys[id]?.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) return ro;
    return null;
  }

  /// Records the first visible message and the fraction scrolled into it.
  /// At the bottom, records "bottom" so the reader stays at the bottom.
  ScrollAnchor? captureAnchor() {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return null;
    }
    if (nearBottom) return const ScrollAnchor.bottom();
    final vp = _viewport;
    if (vp == null) return null;
    ScrollAnchor? best;
    var bestTop = double.infinity;
    for (final e in widget.entries) {
      if (!e.isMessage) continue;
      final box = _boxFor(e.id);
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: vp).dy;
      final h = box.size.height;
      if (top + h <= 0) continue; // entirely above the viewport
      if (top < bestTop) {
        bestTop = top;
        best = ScrollAnchor(e.id, h <= 0 ? 0 : (-top / h).clamp(0.0, 1.0));
      }
    }
    return best;
  }

  void _scheduleRestore(ScrollAnchor a) {
    _passes = 0;
    _attempts = 0;
    _lastMax = -1;
    SchedulerBinding.instance.addPostFrameCallback((_) => _restore(a));
  }

  void _finishRestore() {
    if (!mounted || _ready) return;
    setState(() => _ready = true);
    _near = nearBottom;
    widget.onNearBottomChanged?.call(_near);
  }

  void _next(ScrollAnchor a) {
    SchedulerBinding.instance.addPostFrameCallback((_) => _restore(a));
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Iterative: lazily built lists only know their size once items are built,
  /// so jump to an estimate, let the target build, then correct exactly.
  void _restore(ScrollAnchor a) {
    if (!mounted || _ready) return;
    if (++_attempts > _maxAttempts) return _finishRestore();
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return _next(a);
    }
    final p = _controller.position;

    if (a.atBottom) {
      jumpToBottom();
      final max = p.maxScrollExtent;
      final stable = (max - _lastMax).abs() < 1;
      _lastMax = max;
      if (stable || widget.reversed || _attempts >= 6) return _finishRestore();
      return _next(a);
    }

    final vp = _viewport;
    final box = _boxFor(a.messageId!);
    if (vp != null && box != null) {
      final top = box.localToGlobal(Offset.zero, ancestor: vp).dy;
      final point = top + a.fraction * box.size.height;
      final np = (widget.reversed ? p.pixels - point : p.pixels + point).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      );
      if ((np - p.pixels).abs() > 0.5) _controller.jumpTo(np);
      // One more pass: building items around the target can shift extents.
      if (++_passes >= 2) return _finishRestore();
      return _next(a);
    }

    // Target not built yet: jump near it by average height, then retry.
    final ids = widget.entries.map((e) => e.id).toList();
    final idx = ids.indexOf(a.messageId!);
    if (idx < 0) return _finishRestore();
    var sum = 0.0, n = 0;
    for (final id in ids) {
      final b = _boxFor(id);
      if (b != null) {
        sum += b.size.height;
        n++;
      }
    }
    final avg = n == 0 ? 120.0 : sum / n;
    final target = widget.reversed ? (ids.length - 1 - idx) * avg : idx * avg;
    _controller.jumpTo(target.clamp(p.minScrollExtent, p.maxScrollExtent));
    _next(a);
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final indexOfKey = <Key, int>{};
    for (var i = 0; i < entries.length; i++) {
      final list = widget.reversed ? entries.length - 1 - i : i;
      indexOfKey[_keyFor(entries[i].id)] = list;
    }

    return LayoutBuilder(
      builder: (context, box) {
        var pad = widget.padding;
        final cap = widget.maxContentWidth;
        if (cap != null) {
          final side = (box.maxWidth - cap) / 2;
          if (side > pad.left) pad = EdgeInsets.symmetric(horizontal: side);
        }
        return AnimatedOpacity(
          opacity: _ready ? 1 : 0,
          duration: reduceMotion(context) ? Duration.zero : Motion.press,
          child: ListView.builder(
            key: _viewportKey,
            controller: _controller,
            reverse: widget.reversed,
            scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
            padding: pad.copyWith(
              top: widget.verticalPadding,
              bottom: widget.verticalPadding,
            ),
            itemCount: entries.length,
            findChildIndexCallback: (key) => indexOfKey[key],
            itemBuilder: (context, i) {
              final e = entries[widget.reversed ? entries.length - 1 - i : i];
              return KeyedSubtree(
                key: _keyFor(e.id),
                child: e.builder(context),
              );
            },
          ),
        );
      },
    );
  }
}
