import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A shared world. Different universes keep separate timelines.
@immutable
class Universe {
  const Universe({
    required this.id,
    required this.name,
    required this.era,
    required this.tile,
    required this.description,
  });

  final String id;
  final String name;
  final String era;
  final Color tile;
  final String description;

  Universe copyWith({String? name, String? era, String? description}) =>
      Universe(
        id: id,
        name: name ?? this.name,
        era: era ?? this.era,
        tile: tile,
        description: description ?? this.description,
      );
}

enum MemoryCategory {
  important(
    'Important Memories',
    'Important',
    'Big moments the story should never forget.',
  ),
  facts('Story Facts', 'Story fact', 'Things that are true in this story.'),
  relationships(
    'Character Relationships',
    'Relationship',
    'How characters feel about each other.',
  ),
  world(
    'World Details',
    'World detail',
    'Places, history and how the world works.',
  );

  const MemoryCategory(this.label, this.shortLabel, this.hint);
  final String label;
  final String shortLabel;
  final String hint;
}

@immutable
class Memory {
  const Memory({
    required this.id,
    required this.universeId,
    required this.category,
    required this.text,
    this.pinned = false,
  });

  final String id;
  final String universeId;
  final MemoryCategory category;
  final String text;
  final bool pinned;

  Memory copyWith({MemoryCategory? category, String? text, bool? pinned}) =>
      Memory(
        id: id,
        universeId: universeId,
        category: category ?? this.category,
        text: text ?? this.text,
        pinned: pinned ?? this.pinned,
      );
}

/// Who the user plays as. "Just me" is the no-persona option.
@immutable
class Persona {
  const Persona({
    required this.id,
    required this.name,
    required this.initial,
    required this.description,
  });

  final String id;
  final String name;
  final String initial;
  final String description;
}
