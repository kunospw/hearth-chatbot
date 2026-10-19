import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';

enum ReplyLength {
  short('Short', 300),
  medium('Medium', 600),
  long('Long', 1000);

  const ReplyLength(this.label, this.maxTokens);
  final String label;

  /// What this setting asks for under the hood (shown only in Advanced).
  final int maxTokens;
}

enum WritingStyle {
  casual('Casual'),
  descriptive('Descriptive'),
  literary('Literary');

  const WritingStyle(this.label);
  final String label;
}

enum Creativity {
  steady(
    'Steady',
    0.6,
    'Stays close to the character and plot. Fewer surprises.',
  ),
  balanced(
    'Balanced',
    0.9,
    'A good mix of consistency and surprise. Recommended.',
  ),
  wild(
    'Adventurous',
    1.3,
    'Takes bold turns and invents freely. May drift off-script.',
  );

  const Creativity(this.label, this.temperature, this.hint);
  final String label;
  final double temperature;
  final String hint;
}

/// The technical controls, only ever shown under AI settings → Advanced.
@immutable
class AdvancedAi {
  const AdvancedAi({
    this.temperature = 0.9,
    this.maxTokens = 600,
    this.contextDepth = 40,
    this.repetitionPenalty = 1.1,
  });

  final double temperature;
  final int maxTokens;
  final int contextDepth;
  final double repetitionPenalty;

  AdvancedAi copyWith({
    double? temperature,
    int? maxTokens,
    int? contextDepth,
    double? repetitionPenalty,
  }) => AdvancedAi(
    temperature: temperature ?? this.temperature,
    maxTokens: maxTokens ?? this.maxTokens,
    contextDepth: contextDepth ?? this.contextDepth,
    repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
  );
}

@immutable
class AiPrefs {
  const AiPrefs({
    this.length = ReplyLength.medium,
    this.style = WritingStyle.descriptive,
    this.creativity = Creativity.balanced,
    this.advanced = const AdvancedAi(),
  });

  final ReplyLength length;
  final WritingStyle style;
  final Creativity creativity;
  final AdvancedAi advanced;

  AiPrefs copyWith({
    ReplyLength? length,
    WritingStyle? style,
    Creativity? creativity,
    AdvancedAi? advanced,
  }) => AiPrefs(
    length: length ?? this.length,
    style: style ?? this.style,
    creativity: creativity ?? this.creativity,
    advanced: advanced ?? this.advanced,
  );
}

class AiPrefsNotifier extends Notifier<AiPrefs> {
  static const _k = 'ai.';

  @override
  AiPrefs build() {
    final p = ref.read(sharedPreferencesProvider);
    final len =
        ReplyLength.values.asNameMap()[p.getString('${_k}length')] ??
        ReplyLength.medium;
    final cre =
        Creativity.values.asNameMap()[p.getString('${_k}creativity')] ??
        Creativity.balanced;
    return AiPrefs(
      length: len,
      style:
          WritingStyle.values.asNameMap()[p.getString('${_k}style')] ??
          WritingStyle.descriptive,
      creativity: cre,
      advanced: AdvancedAi(
        temperature: p.getDouble('${_k}temp') ?? cre.temperature,
        maxTokens: p.getInt('${_k}maxTokens') ?? len.maxTokens,
        contextDepth: p.getInt('${_k}depth') ?? 40,
        repetitionPenalty: p.getDouble('${_k}rep') ?? 1.1,
      ),
    );
  }

  void _set(AiPrefs next) {
    state = next;
    final p = ref.read(sharedPreferencesProvider);
    p.setString('${_k}length', next.length.name);
    p.setString('${_k}style', next.style.name);
    p.setString('${_k}creativity', next.creativity.name);
    p.setDouble('${_k}temp', next.advanced.temperature);
    p.setInt('${_k}maxTokens', next.advanced.maxTokens);
    p.setInt('${_k}depth', next.advanced.contextDepth);
    p.setDouble('${_k}rep', next.advanced.repetitionPenalty);
  }

  /// Response length also sets the reply cap, as the Advanced help text says.
  void setLength(ReplyLength v) => _set(
    state.copyWith(
      length: v,
      advanced: state.advanced.copyWith(maxTokens: v.maxTokens),
    ),
  );

  void setStyle(WritingStyle v) => _set(state.copyWith(style: v));

  /// Creativity also sets the randomness, as the Advanced help text says.
  void setCreativity(Creativity v) => _set(
    state.copyWith(
      creativity: v,
      advanced: state.advanced.copyWith(temperature: v.temperature),
    ),
  );

  void setAdvanced(AdvancedAi v) => _set(state.copyWith(advanced: v));

  /// "Reset to defaults" in Advanced: back to what the presets imply, plus
  /// the standard depth and repetition penalty.
  void resetAdvanced() => _set(
    state.copyWith(
      advanced: AdvancedAi(
        temperature: state.creativity.temperature,
        maxTokens: state.length.maxTokens,
      ),
    ),
  );
}

final aiPrefsProvider = NotifierProvider<AiPrefsNotifier, AiPrefs>(
  AiPrefsNotifier.new,
);
