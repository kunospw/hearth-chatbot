import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/util/time_label.dart';
import 'package:hearth/features/characters/data/character_repository.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';
import 'package:hearth/features/library/data/library_repository.dart';
import 'package:hearth/features/library/domain/library_models.dart';
import 'package:hearth/features/settings/data/model_repository.dart';

void main() {
  test('character repository loads the four prototype characters', () async {
    final repo = MockCharacterRepository();
    final all = await repo.list();
    expect(all.map((c) => c.id), ['vesper', 'jun', 'morrow', 'iselde']);
    expect((await repo.byId('vesper'))!.hasPortrait, isTrue);
    expect((await repo.byId('iselde'))!.hasPortrait, isFalse);
    expect(await repo.byId('nope'), isNull);
  });

  test('conversations load newest first and keep alts', () async {
    final now = DateTime(2026, 10, 17, 12);
    final repo = MockConversationRepository(now: now);
    final list = await repo.list();
    expect(list.map((c) => c.id), ['c1', 'c2', 'c3']);
    expect(list.first.pinned, isTrue);
    final c1 = await repo.byId('c1');
    final alts = c1!.messages.firstWhere((m) => m.id == 'c1c');
    expect(alts.alts, hasLength(2));
    expect(alts.role, MessageRole.ai);
    expect(c1.mode, ChatMode.chat);
  });

  test('library repository seeds universes, memories and personas', () async {
    final repo = MockLibraryRepository();
    expect(await repo.universes(), hasLength(3));
    expect(await repo.memories(), hasLength(11));
    final salt = await repo.memories(universeId: 'saltmarsh');
    expect(salt, hasLength(5));
    expect(salt.where((m) => m.pinned), hasLength(2));
    expect(salt.where((m) => m.category == MemoryCategory.important), hasLength(2));
    expect(await repo.personas(), hasLength(2));
  });

  test('models match the prototype', () async {
    final models = await MockModelRepository().list();
    expect(models.map((m) => m.name), ['Ember', 'Lumen', 'Atlas Pro']);
    expect(models[0].dailyFreeReplies, 30);
    expect(models[2].busy, isTrue);
  });

  group('timeLabel', () {
    final now = DateTime(2026, 10, 17, 12); // a Saturday
    test('relative ranges', () {
      expect(timeLabel(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(timeLabel(now.subtract(const Duration(minutes: 2)), now: now), '2m ago');
      expect(timeLabel(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(timeLabel(DateTime(2026, 10, 16, 23), now: now), 'Yesterday');
      expect(timeLabel(DateTime(2026, 10, 14, 9), now: now), 'Wed');
      expect(timeLabel(DateTime(2026, 10, 2, 9), now: now), 'Oct 2');
    });
  });
}
