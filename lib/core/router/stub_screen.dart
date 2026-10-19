import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

/// Placeholder for screens that arrive in later phases. Shows the route and
/// any params so navigation can be verified end to end.
class StubScreen extends StatelessWidget {
  const StubScreen({
    super.key,
    required this.title,
    this.detail,
    this.phase,
    this.showBack = true,
  });

  final String title;
  final String? detail;
  final int? phase;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: showBack, title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail != null) Text(detail!, style: context.ht.body),
              if (phase != null) ...[
                const SizedBox(height: Space.md),
                Text('Arrives in phase $phase', style: context.ht.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
