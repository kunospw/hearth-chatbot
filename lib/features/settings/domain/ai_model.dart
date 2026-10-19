import 'package:flutter/foundation.dart';

/// A selectable reply model. The id is a UI id; the backend maps it to a real
/// provider model (Phase 6).
@immutable
class AiModel {
  const AiModel({
    required this.id,
    required this.name,
    required this.description,
    this.dailyFreeReplies,
    this.busy = false,
  });

  final String id;
  final String name;
  final String description;

  /// Null for models without a free daily allowance.
  final int? dailyFreeReplies;
  final bool busy;
}

/// Why a model can or can't be used right now, for the picker.
@immutable
class ModelStatus {
  const ModelStatus.available(this.repliesLeft)
    : available = true,
      reason = null;
  const ModelStatus.unavailable(this.reason)
    : available = false,
      repliesLeft = null;

  final bool available;
  final int? repliesLeft;
  final String? reason;
}
