import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal loading / error / data switch for [AsyncValue]. Screens that need
/// skeletons or the offline state supply their own [loading] and [error].
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? loading;
  final Widget Function(Object error, StackTrace stack)? error;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          loading?.call() ?? const Center(child: CircularProgressIndicator()),
      error: (e, s) => error?.call(e, s) ?? Center(child: Text('$e')),
    );
  }
}
