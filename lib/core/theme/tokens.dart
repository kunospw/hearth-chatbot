/// Spacing, radius, hit-target and reading tokens (SPEC §3, §10).
/// Colours live in [HearthColors]; never hard-code values in widgets.
library;

import 'package:flutter/animation.dart';

abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double gutter = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Radii {
  static const double field = 12;
  static const double button = 14;
  static const double card = 18;
  static const double sheet = 26;
}

abstract final class Hit {
  /// Primary actions.
  static const double primary = 48;

  /// Inline actions.
  static const double inline = 44;
}

abstract final class Reading {
  static const ({double min, double def, double max}) chatSize = (
    min: 14,
    def: 16,
    max: 22,
  );
  static const ({double min, double def, double max}) storySize = (
    min: 15,
    def: 19,
    max: 26,
  );
  static const double storyMaxWidth = 640;

  /// Line spacing presets: Compact / Comfortable / Roomy.
  static const List<double> chatLineHeights = [1.50, 1.62, 1.80];
  static const List<double> storyLineHeights = [1.58, 1.72, 1.90];

  /// Streaming follows new text only within this distance of the bottom.
  static const double followThreshold = 72;
}

/// Repeated component sizes.
abstract final class Sizes {
  static const double avatar = 48;
  static const double avatarLarge = 56;
  static const double logoSmall = 24;
  static const double logoSplash = 88;
  static const double stroke = 2;
}

abstract final class Motion {
  static const Duration press = Duration(milliseconds: 150);
  static const Duration sheet = Duration(milliseconds: 250);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Gentler motion for content that appears on its own (tab changes, cards
  /// and rows entering): slower, with a soft ease-out so it never snaps.
  static const Duration tab = Duration(milliseconds: 320);
  static const Duration enter = Duration(milliseconds: 480);
  static const Curve soft = Curves.easeOutCubic;
}

/// Breakpoints (SPEC §9).
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
}
