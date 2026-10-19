import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs [action] at most once per [interval], always delivering the latest
/// call: the first call runs immediately, calls inside the window are merged
/// into one trailing run. Used to throttle streaming rebuilds to ~60ms.
class Throttler {
  Throttler(this.interval);

  final Duration interval;
  Timer? _timer;
  VoidCallback? _pending;

  void run(VoidCallback action) {
    if (_timer == null) {
      action();
      _timer = Timer(interval, _tick);
    } else {
      _pending = action;
    }
  }

  void _tick() {
    _timer = null;
    final p = _pending;
    _pending = null;
    if (p != null) {
      p();
      _timer = Timer(interval, _tick);
    }
  }

  /// Runs any pending action now (for example when a stream finishes).
  void flush() {
    _timer?.cancel();
    _timer = null;
    final p = _pending;
    _pending = null;
    p?.call();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
