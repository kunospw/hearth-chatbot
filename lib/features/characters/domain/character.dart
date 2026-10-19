import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A roleplay character. [tile] and [ink] are the character's own colour pair
/// (ink is ≥4.5:1 on tile); the app accent never sits behind a portrait.
@immutable
class Character {
  const Character({
    required this.id,
    required this.name,
    required this.first,
    required this.initial,
    required this.tile,
    required this.ink,
    required this.short,
    this.universeId,
    this.portraitAsset,
    this.portraitUrl,
    this.portraitBytes,
    this.tags = const [],
    this.intro = '',
    this.personality = '',
    this.speaking = '',
    this.greeting = '',
    this.exampleDialogue = '',
    this.rules = '',
    this.relationships = '',
    this.scenario = '',
    this.archived = false,
  });

  final String id;
  final String name;

  /// Short first name used in copy ("Start new chat with Vesper").
  final String first;
  final String initial;
  final Color tile;
  final Color ink;
  final String short;
  final String? universeId;

  /// Bundled portrait (SVG). Preferred over [portraitUrl] when present.
  final String? portraitAsset;
  final String? portraitUrl;

  /// A picture chosen on this device (Phase 6 uploads it and uses a URL).
  final Uint8List? portraitBytes;
  final List<String> tags;
  final String intro;
  final String personality;
  final String speaking;
  final String greeting;
  final String exampleDialogue;
  final String rules;
  final String relationships;
  final String scenario;

  /// Hidden from the main lists (kept, with its chats, until you delete it).
  final bool archived;

  bool get hasPortrait =>
      portraitAsset != null || portraitUrl != null || portraitBytes != null;

  Character copyWith({
    String? id,
    String? name,
    String? first,
    String? initial,
    Color? tile,
    Color? ink,
    String? short,
    String? portraitAsset,
    String? portraitUrl,
    Uint8List? portraitBytes,
    bool clearPortrait = false,
    String? universeId,
    bool clearUniverse = false,
    List<String>? tags,
    String? intro,
    String? personality,
    String? speaking,
    String? greeting,
    String? exampleDialogue,
    String? rules,
    String? relationships,
    String? scenario,
    bool? archived,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      first: first ?? this.first,
      initial: initial ?? this.initial,
      tile: tile ?? this.tile,
      ink: ink ?? this.ink,
      short: short ?? this.short,
      universeId: clearUniverse ? null : (universeId ?? this.universeId),
      portraitAsset: clearPortrait
          ? null
          : (portraitAsset ?? this.portraitAsset),
      portraitUrl: clearPortrait ? null : (portraitUrl ?? this.portraitUrl),
      portraitBytes: clearPortrait
          ? null
          : (portraitBytes ?? this.portraitBytes),
      tags: tags ?? this.tags,
      intro: intro ?? this.intro,
      personality: personality ?? this.personality,
      speaking: speaking ?? this.speaking,
      greeting: greeting ?? this.greeting,
      exampleDialogue: exampleDialogue ?? this.exampleDialogue,
      rules: rules ?? this.rules,
      relationships: relationships ?? this.relationships,
      scenario: scenario ?? this.scenario,
      archived: archived ?? this.archived,
    );
  }
}
