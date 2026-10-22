import 'package:flutter/foundation.dart';

import '../../../data/mock/mock_data.dart';
import '../../relationship/domain/relationship_models.dart';
import 'character.dart';

/// The greeting written for you when the field is left blank: a first line
/// that fits how you know each other.
String defaultGreeting(String first, StartingPoint start) => switch (start) {
  StartingPoint.strangers =>
    '*$first looks up as you arrive.* "Oh — hello. I wasn\'t expecting anyone tonight."',
  StartingPoint.friends =>
    '*$first grins the moment you walk in.* "There you are! Sit down — I saved you a seat."',
  StartingPoint.together =>
    '*$first looks up as you come in, and smiles.* "There you are. I missed you today."',
  StartingPoint.family =>
    '*$first waves you over.* "Hey, you. Come sit — tell me everything."',
  StartingPoint.rivals =>
    '*$first looks up, unimpressed.* "You. Of course it\'s you."',
};

/// Everything the character editor edits. Only [name] is required.
@immutable
class CharacterForm {
  const CharacterForm({
    this.name = '',
    this.short = '',
    this.personality = '',
    this.greeting = '',
    this.backstory = '',
    this.speaking = '',
    this.examples = '',
    this.rules = '',
    this.relationships = '',
    this.scenario = '',
    this.startingPoint = StartingPoint.strangers,
    this.universeId,
    this.swatch = 0,
    this.imageBytes,
    this.imageRemoved = false,
  });

  final String name;
  final String short;
  final String personality;
  final String greeting;
  final String backstory;
  final String speaking;
  final String examples;
  final String rules;
  final String relationships;
  final String scenario;

  /// How you know each other when a story with them begins.
  final StartingPoint startingPoint;
  final String? universeId;

  /// Index into [MockData.swatches]; the colour behind the initial.
  final int swatch;

  /// A newly chosen picture.
  final Uint8List? imageBytes;

  /// The existing picture was removed.
  final bool imageRemoved;

  bool get hasName => name.trim().isNotEmpty;

  /// Nothing typed or chosen yet (a blank new character).
  bool get isBlank => this == const CharacterForm();

  /// The first word of the name; used in copy ("Vesper is writing…").
  String get first {
    final n = name.trim();
    return n.isEmpty ? '' : n.split(RegExp(r'\s+')).first;
  }

  CharacterForm copyWith({
    String? name,
    String? short,
    String? personality,
    String? greeting,
    String? backstory,
    String? speaking,
    String? examples,
    String? rules,
    String? relationships,
    String? scenario,
    StartingPoint? startingPoint,
    String? universeId,
    bool clearUniverse = false,
    int? swatch,
    Uint8List? imageBytes,
    bool? imageRemoved,
    bool clearImageBytes = false,
  }) => CharacterForm(
    name: name ?? this.name,
    short: short ?? this.short,
    personality: personality ?? this.personality,
    greeting: greeting ?? this.greeting,
    backstory: backstory ?? this.backstory,
    speaking: speaking ?? this.speaking,
    examples: examples ?? this.examples,
    rules: rules ?? this.rules,
    relationships: relationships ?? this.relationships,
    scenario: scenario ?? this.scenario,
    startingPoint: startingPoint ?? this.startingPoint,
    universeId: clearUniverse ? null : (universeId ?? this.universeId),
    swatch: swatch ?? this.swatch,
    imageBytes: clearImageBytes ? null : (imageBytes ?? this.imageBytes),
    imageRemoved: imageRemoved ?? this.imageRemoved,
  );

  /// The form for editing an existing character (its introduction is the
  /// backstory field, as in the prototype).
  factory CharacterForm.fromCharacter(Character c) {
    var sw = MockData.swatches.indexWhere((s) => s.tile == c.tile);
    if (sw < 0) sw = 0;
    return CharacterForm(
      name: c.name,
      short: c.short,
      personality: c.personality,
      greeting: c.greeting,
      backstory: c.intro,
      speaking: c.speaking,
      examples: c.exampleDialogue,
      rules: c.rules,
      relationships: c.relationships,
      scenario: c.scenario,
      startingPoint: c.startingPoint,
      universeId: c.universeId,
      swatch: sw,
    );
  }

  /// Builds the character to save. Blank optional fields get the same gentle
  /// defaults as the prototype. [base] is the character being edited.
  Character toCharacter(String id, {Character? base}) {
    final n = name.trim();
    final f = first;
    final sw = MockData.swatches[swatch.clamp(0, MockData.swatches.length - 1)];
    String orElse(String v, String fallback) =>
        v.trim().isEmpty ? fallback : v.trim();
    final shortText = orElse(
      short,
      'A new character, waiting for their story.',
    );
    final keepPicture = imageBytes == null && !imageRemoved;
    return Character(
      id: id,
      name: n,
      first: f,
      initial: f.isEmpty ? '?' : f.substring(0, 1).toUpperCase(),
      tile: sw.tile,
      ink: sw.ink,
      short: shortText,
      universeId: universeId,
      portraitAsset: keepPicture ? base?.portraitAsset : null,
      portraitUrl: keepPicture ? base?.portraitUrl : null,
      portraitBytes: imageBytes ?? (keepPicture ? base?.portraitBytes : null),
      tags: base?.tags ?? const ['Original'],
      intro: backstory.trim().isNotEmpty
          ? backstory.trim()
          : short.trim().isNotEmpty
          ? short.trim()
          : 'Not much is known about $f yet — you’ll find out together.',
      personality: orElse(personality, 'Still taking shape.'),
      speaking: orElse(speaking, 'Natural and conversational.'),
      greeting: orElse(greeting, defaultGreeting(f, startingPoint)),
      exampleDialogue: examples.trim(),
      rules: rules.trim(),
      relationships: relationships.trim(),
      scenario: scenario.trim(),
      startingPoint: startingPoint,
      archived: base?.archived ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CharacterForm &&
      other.name == name &&
      other.short == short &&
      other.personality == personality &&
      other.greeting == greeting &&
      other.backstory == backstory &&
      other.speaking == speaking &&
      other.examples == examples &&
      other.rules == rules &&
      other.relationships == relationships &&
      other.scenario == scenario &&
      other.startingPoint == startingPoint &&
      other.universeId == universeId &&
      other.swatch == swatch &&
      identical(other.imageBytes, imageBytes) &&
      other.imageRemoved == imageRemoved;

  @override
  int get hashCode => Object.hash(
    name,
    short,
    personality,
    greeting,
    backstory,
    speaking,
    examples,
    rules,
    relationships,
    scenario,
    startingPoint,
    universeId,
    swatch,
    imageRemoved,
  );
}

/// An unfinished character saved to come back to.
@immutable
class CharacterDraft {
  const CharacterDraft({required this.id, required this.form, this.editingId});

  final String id;
  final CharacterForm form;

  /// Set when the draft is an edit of an existing character.
  final String? editingId;
}
