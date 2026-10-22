import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/backend/backend_api.dart';
import 'package:hearth/core/backend/mappers.dart';
import 'package:hearth/features/characters/data/supabase_character_repository.dart';
import 'package:hearth/features/characters/domain/character.dart';
import 'package:hearth/features/chat/data/supabase_conversation_repository.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';
import 'package:hearth/features/library/data/supabase_library_repository.dart';
import 'package:hearth/features/library/domain/library_models.dart';
import 'package:hearth/features/relationship/domain/relationship_models.dart';
import 'package:hearth/features/settings/data/supabase_model_repository.dart';

import 'support/fake_backend.dart';

const _vesper = Character(
  id: 'c-1',
  name: 'Vesper Hale',
  first: 'Vesper',
  initial: 'V',
  tile: Color(0xFF24383C),
  ink: Color(0xFFBFD9D6),
  short: 'A weary lighthouse keeper',
  universeId: 'u-1',
  portraitAsset: 'assets/portraits/vesper.svg',
  tags: ['Mystery', 'Gothic'],
  intro: 'Keeps the light.',
  personality: 'Dry.',
  speaking: 'Short.',
  greeting: 'The lamp is lit.',
  exampleDialogue: 'A: hi',
  rules: 'No spoilers.',
  relationships: 'Alone.',
  scenario: 'A storm.',
);

Stream<List<int>> _chunks(String s, int size) async* {
  final bytes = utf8.encode(s);
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
  }
}

void main() {
  group('server-sent events', () {
    const wire = 'event: start\ndata: {"a":1}\n\nevent: delta\ndata: {"text":"héllo — ✓"}\n\nevent: done\ndata: {"text":"x"}\n\n';

    test('events are read whole, however the bytes are split (even inside a character)', () async {
      for (final size in [1, 2, 5, 1000]) {
        final events = await parseSse(_chunks(wire, size)).toList();
        expect(events.map((e) => e.event), ['start', 'delta', 'done'], reason: 'size $size');
        expect(events[1].data['text'], 'héllo — ✓');
      }
    });

    test('cancelling reaches the source at once, even between chunks', () async {
      var cancelled = false;
      final source = StreamController<List<int>>(onCancel: () => cancelled = true);
      final sub = parseSse(source.stream).listen((_) {});
      source.add(utf8.encode('event: start\ndata: {}\n\n'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel().timeout(const Duration(seconds: 1));
      expect(cancelled, isTrue);
    });

    test('CRLF, comments, bad JSON and a last event without a blank line', () async {
      final events = await parseSse(_chunks(
        ': ping\r\n\r\nevent: delta\r\ndata: {not json}\r\n\r\nevent: done\r\ndata: {"ok":true}',
        3,
      )).toList();
      expect(events.length, 1);
      expect(events.single.event, 'done');
      expect(events.single.data, {'ok': true});
    });
  });

  group('mappers', () {
    test('a character survives a round trip through its row', () {
      final row = characterToRow(_vesper, userId: 'u');
      expect(row['user_id'], 'u');
      expect(row['tile_color'], 0xFF24383C);
      final back = characterFromRow(row);
      expect(back.name, _vesper.name);
      expect(back.tile, _vesper.tile);
      expect(back.ink, _vesper.ink);
      expect(back.tags, _vesper.tags);
      expect(back.exampleDialogue, _vesper.exampleDialogue);
      expect(back.portraitAsset, _vesper.portraitAsset);
      expect(back.universeId, 'u-1');
    });

    test('a character keeps its starting point; an unknown one reads as Just met', () {
      final row = characterToRow(_vesper.copyWith(startingPoint: StartingPoint.together), userId: 'u');
      expect(row['starting_point'], 'together');
      expect(characterFromRow(row).startingPoint, StartingPoint.together);
      expect(characterFromRow({...row, 'starting_point': 'pen-pals'}).startingPoint, StartingPoint.strangers);
      expect(characterFromRow({...row}..remove('starting_point')).startingPoint, StartingPoint.strangers);
    });

    test('library rows keep their category, pin and colour', () {
      final u = universeFromRow(universeToRow(
          const Universe(id: 'u', name: 'World', era: 'Era', tile: Color(0xFF4A3620), description: 'd'),
          userId: 'x'));
      expect(u.tile, const Color(0xFF4A3620));
      final m = memoryFromRow(memoryToRow(
          const Memory(id: 'm', universeId: 'u', category: MemoryCategory.world, text: 't', pinned: true),
          userId: 'x'));
      expect(m.category, MemoryCategory.world);
      expect(m.pinned, isTrue);
      expect(memoryFromRow({'id': 'm', 'universe_id': 'u', 'category': 'nonsense', 'text': 't'}).category,
          MemoryCategory.facts);
    });

    test('a message keeps its versions and the notes under each one', () {
      const m = Message(
        id: 'm',
        role: MessageRole.ai,
        alts: ['one', 'two'],
        altIndex: 1,
        notes: {1: RelationshipNote(text: 'Trust grew', story: 'Something shifted.', entryId: 'e1')},
      );
      final row = messageToRow(m, conversationId: 'c', userId: 'u');
      expect(row['notes'], {'1': isA<Map>()});
      final back = messageFromRow(jsonDecode(jsonEncode(row)) as Map<String, dynamic>);
      expect(back.alts, ['one', 'two']);
      expect(back.altIndex, 1);
      expect(back.note?.text, 'Trust grew');
      expect(back.note?.entryId, 'e1');
      expect(back.notes.containsKey(0), isFalse);
    });

    test('a user message row is a user message; an empty version list still shows something', () {
      final u = messageFromRow({'id': 'a', 'role': 'user', 'alts': ['hi'], 'alt_index': 0, 'notes': {}});
      expect(u.isUser, isTrue);
      expect(messageFromRow({'id': 'a', 'role': 'ai', 'alts': [], 'alt_index': 0, 'notes': {}}).text, '');
    });
  });

  group('characters', () {
    test('save writes your row (with your id); list is newest first; a new picture is uploaded', () async {
      final api = FakeBackendApi();
      final repo = SupabaseCharacterRepository(api);
      await repo.save(_vesper);
      await repo.save(_vesper.copyWith(id: 'c-2', name: 'Jun', portraitBytes: Uint8List.fromList([1, 2, 3])));
      expect(api.uploads, hasLength(1));
      final rows = api.table('characters');
      expect(rows.every((r) => r['user_id'] == 'user-1'), isTrue);
      expect(rows.last['portrait_url'], 'https://example.test/portraits/1.jpg');
      // the fake orders by a column the real database fills in; here: order by name for a stable check
      api.table('characters')[0]['created_at'] = '2026-01-01';
      api.table('characters')[1]['created_at'] = '2026-02-01';
      final list = await repo.list();
      expect(list.map((c) => c.id), ['c-2', 'c-1']);
      expect((await repo.byId('c-1'))?.name, 'Vesper Hale');
      expect(await repo.byId('nope'), isNull);
    });

    test('saving twice replaces (edit), and signed out refuses', () async {
      final api = FakeBackendApi();
      final repo = SupabaseCharacterRepository(api);
      await repo.save(_vesper);
      await repo.save(_vesper.copyWith(name: 'Vesper H.'));
      expect(api.table('characters'), hasLength(1));
      expect(api.table('characters').single['name'], 'Vesper H.');
      api.userId = null;
      await expectLater(repo.save(_vesper), throwsA(isA<BackendException>()));
    });
  });

  group('library', () {
    test('universes, memories (in order, by universe) and personas ("Just me" first)', () async {
      final api = FakeBackendApi();
      final repo = SupabaseLibraryRepository(api);
      await repo.saveUniverse(const Universe(id: 'u1', name: 'A', era: 'e', tile: Color(0xFF111111), description: ''));
      await repo.saveMemory(const Memory(id: 'm1', universeId: 'u1', category: MemoryCategory.facts, text: 'one'));
      await repo.saveMemory(const Memory(id: 'm2', universeId: 'u2', category: MemoryCategory.facts, text: 'two'));
      api.table('memories')[0]['pos'] = 2;
      api.table('memories')[1]['pos'] = 1;
      expect((await repo.memories()).map((m) => m.id), ['m2', 'm1']);
      expect((await repo.memories(universeId: 'u1')).map((m) => m.id), ['m1']);
      await repo.deleteMemory('m1');
      expect(await repo.memories(universeId: 'u1'), isEmpty);
      expect((await repo.universeById('u1'))?.name, 'A');

      api.table('personas').addAll([
        {'id': 'p-wren', 'name': 'Wren', 'initial': 'W', 'description': '', 'created_at': '2026-02-01', 'is_default': false},
        {'id': 'p-me', 'name': 'Just me', 'initial': 'M', 'description': '', 'created_at': '2026-03-01', 'is_default': true},
      ]);
      expect((await repo.personas()).map((p) => p.id), ['p-me', 'p-wren']);
      await repo.savePersona(const Persona(id: 'p-new', name: 'Ash', initial: 'A', description: ''));
      expect(api.table('personas').last['user_id'], 'user-1');
    });
  });

  group('models', () {
    test('only the friendly columns are asked for; usage is today’s', () async {
      final api = FakeBackendApi();
      api.table('models').addAll([
        {'id': 'ember', 'name': 'Ember', 'description': 'd', 'daily_free_replies': 30, 'busy': false, 'sort': 1},
        {'id': 'atlas', 'name': 'Atlas Pro', 'description': 'd', 'daily_free_replies': null, 'busy': true, 'sort': 2},
      ]);
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      api.table('model_usage').addAll([
        {'model_id': 'ember', 'day': today, 'used': 4},
        {'model_id': 'ember', 'day': '2000-01-01', 'used': 29},
      ]);
      final repo = SupabaseModelRepository(api);
      final models = await repo.list();
      expect(models.map((m) => (m.id, m.dailyFreeReplies, m.busy)), [('ember', 30, false), ('atlas', null, true)]);
      expect(await repo.usedToday(), {'ember': 4});
    });
  });

  group('conversations', () {
    Conversation conv({List<Message>? messages, String title = 'First', bool pinned = false}) => Conversation(
          id: 'cv-1',
          characterId: 'c-1',
          title: title,
          updatedAt: DateTime.utc(2026, 3, 10, 9),
          pinned: pinned,
          messages: messages ??
              const [
                Message(id: 'm1', role: MessageRole.ai, alts: ['hello']),
                Message(id: 'm2', role: MessageRole.user, alts: ['hi']),
              ],
        );

    test('saves are held back while a reply streams, then written once with only what changed', () async {
      final api = FakeBackendApi();
      final repo = SupabaseConversationRepository(api, quiet: const Duration(milliseconds: 50));
      var c = conv();
      for (var i = 0; i < 10; i++) {
        c = c.copyWith(messages: [...c.messages.take(2), Message(id: 'm3', role: MessageRole.ai, alts: ['word ' * i])]);
        await repo.save(c);
      }
      expect(api.log.where((l) => l.startsWith('upsert')), isEmpty, reason: 'nothing written while it keeps changing');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.table('conversations'), hasLength(1));
      expect(api.table('messages').map((r) => r['id']), ['m1', 'm2', 'm3']);
      expect((api.table('messages').last['alts'] as List).single, 'word ' * 9);
      expect(api.table('messages').every((r) => r['user_id'] == 'user-1' && r['conversation_id'] == 'cv-1'), isTrue);

      // a later edit sends just the message that changed
      api.log.clear();
      await repo.save(c.copyWith(messages: [c.messages[0], c.messages[1].copyWith(alts: ['hi again']), c.messages[2]]));
      await repo.flush('cv-1');
      expect(api.log, ['upsert conversations', 'upsert messages'].where((l) => l == 'upsert messages'));
      expect(api.table('messages').firstWhere((r) => r['id'] == 'm2')['alts'], ['hi again']);
    });

    test('flush writes at once (the server reads your messages from the database)', () async {
      final api = FakeBackendApi();
      final repo = SupabaseConversationRepository(api, quiet: const Duration(minutes: 5));
      await repo.save(conv());
      expect(api.table('messages'), isEmpty);
      await repo.flush('cv-1');
      expect(api.table('messages'), hasLength(2));
    });

    test('removed messages are deleted; unchanged conversations write nothing', () async {
      final api = FakeBackendApi();
      final repo = SupabaseConversationRepository(api, quiet: const Duration(minutes: 5));
      await repo.save(conv());
      await repo.flush('cv-1');
      api.log.clear();
      await repo.save(conv());
      await repo.flush('cv-1');
      expect(api.log, isEmpty);
      await repo.save(conv(messages: const [Message(id: 'm1', role: MessageRole.ai, alts: ['hello'])]));
      await repo.flush('cv-1');
      expect(api.table('messages').map((r) => r['id']), ['m1']);
    });

    test('list and byId rebuild the conversation, messages in order', () async {
      final api = FakeBackendApi();
      final repo = SupabaseConversationRepository(api, quiet: const Duration(minutes: 5));
      await repo.save(conv(title: 'The letter', pinned: true));
      await repo.flush('cv-1');
      for (var i = 0; i < api.table('messages').length; i++) {
        api.table('messages')[i]['seq'] = 10 - i; // the database orders by seq
      }
      final fresh = SupabaseConversationRepository(api);
      final all = await fresh.list();
      expect(all.single.title, 'The letter');
      expect(all.single.pinned, isTrue);
      expect(all.single.messages.map((m) => m.id), ['m2', 'm1']);
      expect((await fresh.byId('cv-1'))?.messages, hasLength(2));
      expect(await fresh.byId('zzz'), isNull);
    });

    test('a failed write is kept and tried again; deleting removes the chat', () async {
      final api = FakeBackendApi();
      final repo = SupabaseConversationRepository(api, quiet: const Duration(minutes: 5));
      await repo.save(conv());
      api.offline = true;
      await expectLater(repo.flush('cv-1'), throwsA(isA<OfflineBackendException>()));
      expect(api.table('messages'), isEmpty);
      api.offline = false;
      await repo.flush('cv-1'); // the pending version was kept
      expect(api.table('messages'), hasLength(2));
      await repo.delete('cv-1');
      expect(api.table('conversations'), isEmpty);
    });
  });
}
