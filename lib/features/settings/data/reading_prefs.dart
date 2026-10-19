import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/tokens.dart';

enum Narration {
  first('I / me'),
  second('You'),
  third('She / he');

  const Narration(this.label);
  final String label;
}

enum Pacing {
  slow('Slow'),
  balanced('Balanced'),
  brisk('Brisk');

  const Pacing(this.label);
  final String label;
}

/// Line spacing presets, shared by chat and story (index into
/// [Reading.chatLineHeights] / [Reading.storyLineHeights]).
const lineSpacingLabels = ['Compact', 'Comfortable', 'Roomy'];

@immutable
class ReadingPrefs {
  const ReadingPrefs({
    this.chatSize = 16,
    this.storySize = 19,
    this.lineSpacing = 1,
    this.narration = Narration.third,
    this.pacing = Pacing.balanced,
  });

  final double chatSize;
  final double storySize;

  /// 0 Compact · 1 Comfortable · 2 Roomy.
  final int lineSpacing;
  final Narration narration;
  final Pacing pacing;

  double get chatLineHeight => Reading.chatLineHeights[lineSpacing];
  double get storyLineHeight => Reading.storyLineHeights[lineSpacing];

  ReadingPrefs copyWith({
    double? chatSize,
    double? storySize,
    int? lineSpacing,
    Narration? narration,
    Pacing? pacing,
  }) => ReadingPrefs(
    chatSize: (chatSize ?? this.chatSize).clamp(
      Reading.chatSize.min,
      Reading.chatSize.max,
    ),
    storySize: (storySize ?? this.storySize).clamp(
      Reading.storySize.min,
      Reading.storySize.max,
    ),
    lineSpacing: (lineSpacing ?? this.lineSpacing).clamp(0, 2),
    narration: narration ?? this.narration,
    pacing: pacing ?? this.pacing,
  );
}

class ReadingPrefsNotifier extends Notifier<ReadingPrefs> {
  static const _k = 'reading.';

  @override
  ReadingPrefs build() {
    final p = ref.read(sharedPreferencesProvider);
    return const ReadingPrefs().copyWith(
      chatSize: p.getDouble('${_k}chatSize'),
      storySize: p.getDouble('${_k}storySize'),
      lineSpacing: p.getInt('${_k}lineSpacing'),
      narration: Narration.values.asNameMap()[p.getString('${_k}narration')],
      pacing: Pacing.values.asNameMap()[p.getString('${_k}pacing')],
    );
  }

  void _set(ReadingPrefs next) {
    state = next;
    final p = ref.read(sharedPreferencesProvider);
    p.setDouble('${_k}chatSize', next.chatSize);
    p.setDouble('${_k}storySize', next.storySize);
    p.setInt('${_k}lineSpacing', next.lineSpacing);
    p.setString('${_k}narration', next.narration.name);
    p.setString('${_k}pacing', next.pacing.name);
  }

  void setChatSize(double v) => _set(state.copyWith(chatSize: v));
  void setStorySize(double v) => _set(state.copyWith(storySize: v));
  void setLineSpacing(int v) => _set(state.copyWith(lineSpacing: v));
  void setNarration(Narration v) => _set(state.copyWith(narration: v));
  void setPacing(Pacing v) => _set(state.copyWith(pacing: v));
}

final readingPrefsProvider =
    NotifierProvider<ReadingPrefsNotifier, ReadingPrefs>(
      ReadingPrefsNotifier.new,
    );
