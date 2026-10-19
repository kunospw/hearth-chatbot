import 'package:flutter/foundation.dart';

import '../../relationship/domain/relationship_models.dart';

enum ChatMode { chat, story }

enum MessageRole { ai, user }

/// A message with alternative versions (Rewrite adds an alt).
/// User messages always have exactly one alt.
@immutable
class Message {
  const Message({
    required this.id,
    required this.role,
    required this.alts,
    this.altIndex = 0,
    this.notes = const {},
  }) : assert(altIndex >= 0);

  final String id;
  final MessageRole role;
  final List<String> alts;
  final int altIndex;

  /// "Trust grew a little": one note per version of the reply (by alt index).
  /// A user message only has index 0.
  final Map<int, RelationshipNote> notes;

  /// The note for the version being shown.
  RelationshipNote? get note => notes[altIndex];

  String get text => alts[altIndex.clamp(0, alts.length - 1)];
  bool get isUser => role == MessageRole.user;

  Message copyWith({
    List<String>? alts,
    int? altIndex,
    Map<int, RelationshipNote>? notes,
  }) => Message(
    id: id,
    role: role,
    alts: alts ?? this.alts,
    altIndex: altIndex ?? this.altIndex,
    notes: notes ?? this.notes,
  );
}

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.characterId,
    required this.title,
    required this.updatedAt,
    required this.messages,
    this.pinned = false,
    this.mode = ChatMode.chat,
    this.archived = false,
    this.personaId,
  });

  final String id;
  final String characterId;
  final String title;
  final DateTime updatedAt;
  final List<Message> messages;
  final bool pinned;

  /// Each conversation remembers its own mode.
  final ChatMode mode;

  /// Hidden from the main chat lists (kept until you delete it).
  final bool archived;

  /// Who you play as in this chat (null = whoever is selected in the Library).
  final String? personaId;

  Message? get last => messages.isEmpty ? null : messages.last;

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<Message>? messages,
    bool? pinned,
    ChatMode? mode,
    bool? archived,
    String? personaId,
  }) => Conversation(
    id: id,
    characterId: characterId,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
    pinned: pinned ?? this.pinned,
    mode: mode ?? this.mode,
    archived: archived ?? this.archived,
    personaId: personaId ?? this.personaId,
  );
}
