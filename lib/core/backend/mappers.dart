import 'package:flutter/painting.dart';

import '../../features/characters/domain/character.dart';
import '../../features/chat/domain/chat_models.dart';
import '../../features/library/domain/library_models.dart';
import '../../features/relationship/domain/relationship_models.dart';
import '../../features/settings/domain/ai_model.dart';

// Rows (snake_case, as the database stores them) <-> the app's models.

int _int(Object? v) => (v as num).toInt();
String _s(Object? v) => (v as String?) ?? '';

// ── characters ────────────────────────────────────────────────────────────

Map<String, Object?> characterToRow(
  Character c, {
  required String userId,
  String? portraitUrl,
}) => {
  'id': c.id,
  'user_id': userId,
  'name': c.name,
  'first': c.first,
  'initial': c.initial,
  'short': c.short,
  'tile_color': c.tile.toARGB32(),
  'ink_color': c.ink.toARGB32(),
  'universe_id': c.universeId,
  'portrait_asset': c.portraitAsset,
  'portrait_url': portraitUrl ?? c.portraitUrl,
  'tags': c.tags,
  'intro': c.intro,
  'personality': c.personality,
  'speaking': c.speaking,
  'greeting': c.greeting,
  'example_dialogue': c.exampleDialogue,
  'rules': c.rules,
  'relationships': c.relationships,
  'scenario': c.scenario,
      'archived': c.archived,
};

Character characterFromRow(Map<String, dynamic> r) => Character(
  id: r['id'] as String,
  name: _s(r['name']),
  first: _s(r['first']),
  initial: _s(r['initial']),
  tile: Color(_int(r['tile_color'])),
  ink: Color(_int(r['ink_color'])),
  short: _s(r['short']),
  universeId: r['universe_id'] as String?,
  portraitAsset: r['portrait_asset'] as String?,
  portraitUrl: r['portrait_url'] as String?,
  tags: [for (final t in (r['tags'] as List? ?? const [])) '$t'],
  intro: _s(r['intro']),
  personality: _s(r['personality']),
  speaking: _s(r['speaking']),
  greeting: _s(r['greeting']),
  exampleDialogue: _s(r['example_dialogue']),
  rules: _s(r['rules']),
  relationships: _s(r['relationships']),
  scenario: _s(r['scenario']),
      archived: r['archived'] == true,
);

// ── library ───────────────────────────────────────────────────────────────

Map<String, Object?> universeToRow(Universe u, {required String userId}) => {
  'id': u.id,
  'user_id': userId,
  'name': u.name,
  'era': u.era,
  'tile_color': u.tile.toARGB32(),
  'description': u.description,
};

Universe universeFromRow(Map<String, dynamic> r) => Universe(
  id: r['id'] as String,
  name: _s(r['name']),
  era: _s(r['era']),
  tile: Color(_int(r['tile_color'])),
  description: _s(r['description']),
);

Map<String, Object?> memoryToRow(Memory m, {required String userId}) => {
  'id': m.id,
  'user_id': userId,
  'universe_id': m.universeId,
  'category': m.category.name,
  'text': m.text,
  'pinned': m.pinned,
};

Memory memoryFromRow(Map<String, dynamic> r) => Memory(
  id: r['id'] as String,
  universeId: r['universe_id'] as String,
  category:
      MemoryCategory.values.asNameMap()[r['category']] ?? MemoryCategory.facts,
  text: _s(r['text']),
  pinned: r['pinned'] == true,
);

Map<String, Object?> personaToRow(Persona p, {required String userId}) => {
  'id': p.id,
  'user_id': userId,
  'name': p.name,
  'initial': p.initial,
  'description': p.description,
};

Persona personaFromRow(Map<String, dynamic> r) => Persona(
  id: r['id'] as String,
  name: _s(r['name']),
  initial: _s(r['initial']),
  description: _s(r['description']),
);

// ── models ────────────────────────────────────────────────────────────────

AiModel modelFromRow(Map<String, dynamic> r) => AiModel(
  id: r['id'] as String,
  name: _s(r['name']),
  description: _s(r['description']),
  dailyFreeReplies: r['daily_free_replies'] == null
      ? null
      : _int(r['daily_free_replies']),
  busy: r['busy'] == true,
);

// ── conversations ─────────────────────────────────────────────────────────

Map<String, Object?> conversationToRow(
  Conversation c, {
  required String userId,
}) => {
  'id': c.id,
  'user_id': userId,
  'character_id': c.characterId,
  'title': c.title,
  'mode': c.mode.name,
  'pinned': c.pinned,
  'archived': c.archived,
  'persona_id': c.personaId,
  'updated_at': c.updatedAt.toUtc().toIso8601String(),
};

Map<String, Object?> noteToJson(RelationshipNote n) => {
  'text': n.text,
  'story': n.story,
  'entryId': n.entryId,
  'kindId': n.kindId,
  'evidence': n.evidence,
  'reason': n.reason,
};

RelationshipNote noteFromJson(Map<String, dynamic> j) => RelationshipNote(
  text: _s(j['text']),
  story: _s(j['story']),
  entryId: j['entryId'] as String?,
  kindId: j['kindId'] as String?,
  evidence: j['evidence'] as String?,
  reason: j['reason'] as String?,
);

Map<String, Object?> messageToRow(
  Message m, {
  required String conversationId,
  required String userId,
}) => {
  'id': m.id,
  'conversation_id': conversationId,
  'user_id': userId,
  'role': m.isUser ? 'user' : 'ai',
  'alts': m.alts,
  'alt_index': m.altIndex,
  'notes': {for (final e in m.notes.entries) '${e.key}': noteToJson(e.value)},
};

Message messageFromRow(Map<String, dynamic> r) {
  final alts = [for (final a in (r['alts'] as List? ?? const [])) '$a'];
  final notes = <int, RelationshipNote>{};
  final raw = r['notes'];
  if (raw is Map) {
    raw.forEach((k, v) {
      final i = int.tryParse('$k');
      if (i != null && v is Map<String, dynamic>) notes[i] = noteFromJson(v);
    });
  }
  return Message(
    id: r['id'] as String,
    role: r['role'] == 'user' ? MessageRole.user : MessageRole.ai,
    alts: alts.isEmpty ? const [''] : alts,
    altIndex: _int(r['alt_index'] ?? 0),
    notes: notes,
  );
}

Conversation conversationFromRow(
  Map<String, dynamic> r,
  List<Message> messages,
) => Conversation(
  id: r['id'] as String,
  characterId: r['character_id'] as String,
  title: _s(r['title']),
  updatedAt:
      DateTime.tryParse(_s(r['updated_at']))?.toLocal() ?? DateTime.now(),
  messages: messages,
  pinned: r['pinned'] == true,
  mode: r['mode'] == 'story' ? ChatMode.story : ChatMode.chat,
  archived: r['archived'] == true,
  personaId: r['persona_id'] as String?,
);
