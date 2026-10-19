import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/sheets.dart';
import '../data/model_usage.dart';

/// "Choose a model": a radio list with each model's availability and, when it
/// can't be used, why. Picking an available model selects it and closes the
/// sheet, returning its id (null if dismissed).
Future<String?> showModelPicker(BuildContext context) {
  return showHearthSheet<String>(
    context,
    builder: (_) => const _ModelPickerBody(),
  );
}

class _ModelPickerBody extends ConsumerWidget {
  const _ModelPickerBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final models = ref.watch(modelCatalogProvider);
    final selected = ref.watch(selectedModelIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'Choose a model'),
        for (final m in models)
          Builder(
            builder: (context) {
              final status = ref.watch(modelStatusProvider(m.id));
              return RadioRow(
                title: m.name,
                subtitle: m.description,
                status: status.line(m),
                statusColor: status.available
                    ? c.ok
                    : (m.busy ? c.pin : c.danger),
                enabled: status.available,
                selected: m.id == selected,
                onTap: () {
                  ref.read(selectedModelIdProvider.notifier).select(m.id);
                  Navigator.of(context).pop(m.id);
                },
              );
            },
          ),
        const SizedBox(height: Space.sm),
        Text(
          'Free models have a daily reply limit. It resets every day at $resetsAtLabel.',
          style: context.ht.caption,
        ),
      ],
    );
  }
}
