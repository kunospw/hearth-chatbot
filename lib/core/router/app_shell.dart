import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../widgets/motion_widgets.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Dest('Characters', Icons.people_outline, Icons.people),
  _Dest('Chats', Icons.chat_bubble_outline, Icons.chat_bubble),
  _Dest('Library', Icons.auto_stories_outlined, Icons.auto_stories),
];

/// Keeps every tab alive (so each keeps its own scroll position and stack) but
/// shows only the selected one, easing it in with a soft fade and a small rise
/// each time you switch. Hidden tabs are fully off-stage, never half-faded on
/// top of the new page, and stop their tickers.
class FadeBranches extends StatefulWidget {
  const FadeBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadeBranches> createState() => _FadeBranchesState();
}

class _FadeBranchesState extends State<FadeBranches>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.tab,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Motion.soft,
  );
  late final Animation<Offset> _rise = Tween(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(_curve);

  @override
  void didUpdateWidget(FadeBranches old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      reduceMotion(context) ? _c.value = 1 : _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Every child is wrapped identically, so switching tabs only changes
    // values and never rebuilds (or loses) a tab's state.
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: i != widget.currentIndex,
            child: TickerMode(
              enabled: i == widget.currentIndex,
              child: FadeTransition(
                opacity: i == widget.currentIndex
                    ? _curve
                    : kAlwaysCompleteAnimation,
                child: SlideTransition(
                  position: i == widget.currentIndex
                      ? _rise
                      : kAlwaysDismissedAnimation.drive(
                          Tween(begin: Offset.zero, end: Offset.zero),
                        ),
                  child: widget.children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom NavigationBar below 600dp, NavigationRail from 600dp (SPEC §9).
/// Back on a tab root goes to Characters first, then exits (SPEC §4).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final index = shell.currentIndex;

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  Expanded(child: shell),
                ],
              )
            : shell,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: _select,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
      ),
    );
  }
}
