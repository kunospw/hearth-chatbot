import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/backend/backend_api.dart';
import 'package:hearth/core/backend/backend_providers.dart';
import 'package:hearth/core/backend/mappers.dart';
import 'package:hearth/core/widgets/composer.dart';
import 'package:hearth/features/auth/data/auth_providers.dart';
import 'package:hearth/features/auth/data/auth_service.dart';
import 'package:hearth/features/characters/domain/character.dart';
import 'package:hearth/features/chat/data/reply_streaming_service.dart';
import 'package:hearth/features/chat/data/server_reply_service.dart';
import 'package:hearth/features/relationship/data/relationship_providers.dart';
import 'package:hearth/features/settings/data/model_usage.dart';
import 'package:hearth/features/settings/data/profile_prefs.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const vesperForDebug = Character(
  id: 'c-vesper',
  name: 'Vesper Hale',
  first: 'Vesper',
  initial: 'V',
  tile: Color(0xFF24383C),
  ink: Color(0xFFBFD9D6),
  short: 'A weary lighthouse keeper',
  greeting: 'The lamp is lit.',
);

/// The server's snapshot (the committed fixture), for this character and persona.
Map<String, dynamic> snapshot() => {
      ...(jsonDecode(File('supabase/tests/golden/snapshot.json').readAsStringSync()) as Map<String, dynamic>),
      'characterId': 'c-vesper',
      'personaId': 'p-me',
    };

/// A small account: one character, one chat, "Just me", a profile.
FakeBackendApi world({bool withCharacter = true}) {
  final api = FakeBackendApi();
  api.table('personas').add({
    'id': 'p-me',
    'name': 'Just me',
    'initial': 'M',
    'description': 'No persona.',
    'is_default': true,
    'created_at': '2026-01-01',
  });
  api.table('profiles').add({'id': 'user-1', 'adult_content': false});
  api.table('models').addAll([
    {'id': 'ember', 'name': 'Ember', 'description': 'Quick', 'daily_free_replies': 30, 'busy': false, 'sort': 1},
    {'id': 'lumen', 'name': 'Lumen', 'description': 'Rich', 'daily_free_replies': 50, 'busy': false, 'sort': 2},
  ]);
  if (withCharacter) {
    api.table('characters').add({...characterToRow(vesperForDebug, userId: 'user-1'), 'created_at': '2026-01-02'});
    api.table('conversations').add({
      'id': 'cv-1',
      'user_id': 'user-1',
      'character_id': 'c-vesper',
      'title': 'The letter',
      'mode': 'chat',
      'pinned': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    api.table('messages').add({
      'id': 'm-ai-1',
      'conversation_id': 'cv-1',
      'user_id': 'user-1',
      'role': 'ai',
      'alts': ['The lamp is lit.'],
      'alt_index': 0,
      'notes': {},
      'seq': 1,
    });
  }
  api.rpcs['ensure_relationship'] = (p) => {
        ...snapshot(),
        'characterId': p['p_character'],
        'personaId': p['p_persona'],
      };
  api.invokes['apply_correction'] = (b) => {'relationship': snapshot(), 'note': null};
  return api;
}

Future<Harness> pumpServer(
  WidgetTester t,
  FakeBackendApi api, {
  FakeAuthService? auth,
  Map<String, Object> prefs = const {},
}) {
  final a = auth ?? FakeAuthService(signedIn: const AuthUser(id: 'user-1', email: 'me@example.com'));
  return pumpHearth(t, prefs: prefs, overrides: [
    backendApiProvider.overrideWithValue(api),
    authServiceProvider.overrideWithValue(a),
    replyStreamingServiceProvider.overrideWith((ref) => ServerReplyStreamingService(api)),
  ]);
}

Finder composerField() => find.descendant(of: find.byType(Composer), matching: find.byType(TextField));

Stream<SseEvent> script(List<(String, Map<String, dynamic>)> list) =>
    Stream.fromIterable([for (final e in list) SseEvent(e.$1, e.$2)]);

const _userNote = {'text': 'Trust grew', 'story': 'Something shifted between you.', 'entryId': 'e-user'};

void main() {
  group('signing in', () {
    testWidgets('nothing shows until you are signed in; a wrong password says so; then your stories appear', (t) async {
      final api = world();
      final auth = FakeAuthService();
      await pumpServer(t, api, auth: auth);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Vesper Hale'), findsNothing);

      final signIn = find.widgetWithText(FilledButton, 'Sign in');
      expect(t.widget<FilledButton>(signIn).onPressed, isNull, reason: 'disabled until both are filled');
      await t.enterText(find.widgetWithText(TextField, 'Email'), 'me@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'wrong password');
      await t.pump();
      await t.tapAndSettle(signIn);
      expect(find.text('That email or password isn’t right.'), findsOneWidget);

      await t.enterText(find.widgetWithText(TextField, 'Password'), FakeAuthService.goodPassword);
      await t.pump();
      await t.tapAndSettle(signIn);
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('Vesper Hale'), findsWidgets);
    });

    testWidgets('creating an account that needs email confirmation says to check the email', (t) async {
      final auth = FakeAuthService()..needsConfirmation = true;
      await pumpServer(t, world(), auth: auth);
      await t.tapAndSettle(find.text('New here? Create an account'));
      expect(find.text('Create your account'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Email'), 'new@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'long enough pw');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Create account'));
      expect(find.textContaining('We sent a link to new@example.com'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('signing out from Settings brings the sign-in screen back', (t) async {
      final auth = FakeAuthService(signedIn: const AuthUser(id: 'user-1', email: 'me@example.com'));
      final h = await pumpServer(t, world(), auth: auth);
      await h.push('/settings');
      expect(find.text('me@example.com'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Sign out'), 300, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tapAndSettle(find.text('Sign out'));
      expect(auth.calls, contains('signOut'));
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('without a server the app opens straight to the sample stories', (t) async {
      await pumpHearth(t);
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    });
  });

  group('your account', () {
    testWidgets('home shows the characters saved in your account', (t) async {
      await pumpServer(t, world());
      expect(find.text('Vesper Hale'), findsWidgets);
      expect(find.text('Jun Okafor'), findsNothing, reason: 'the built-in samples are not mixed in');
    });

    testWidgets('a new account starts empty and can add the sample stories', (t) async {
      final api = world(withCharacter: false);
      await pumpServer(t, api);
      expect(find.text('Your first story starts here'), findsOneWidget);
      await t.tapAndSettle(find.text('Meet the sample characters'));
      expect(api.table('characters'), hasLength(4));
      expect(api.table('characters').every((r) => r['user_id'] == 'user-1'), isTrue);
      expect(api.table('universes'), isNotEmpty);
      // each copy has its own id and points at the copied world
      final ids = api.table('characters').map((r) => r['id']).toSet();
      expect(ids, hasLength(4));
      expect(ids.every((id) => (id as String).length > 20), isTrue);
      final unis = api.table('universes').map((r) => r['id']).toSet();
      expect(api.table('characters').where((r) => r['universe_id'] != null).every((r) => unis.contains(r['universe_id'])), isTrue);
      expect(find.text('Your first story starts here'), findsNothing);
    });

    testWidgets('mature content is off, can be turned on, and is saved to your account', (t) async {
      final api = world();
      final h = await pumpServer(t, api);
      await h.push('/settings');
      final row = find.text('Mature content');
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      expect(h.container.read(matureContentProvider).value, isFalse);
      await t.tapAndSettle(row);
      expect(find.text('Mature content is on'), findsOneWidget);
      expect(api.table('profiles').single['adult_content'], isTrue);
      await t.tapAndSettle(row);
      expect(api.table('profiles').single['adult_content'], isFalse);
    });

    testWidgets('mature content is not offered without an account', (t) async {
      final h = await pumpHearth(t);
      await h.push('/settings');
      expect(find.text('Mature content'), findsNothing);
    });
  });

  group('a chat with the server writing the replies', () {
    Future<Harness> openChat(WidgetTester t, FakeBackendApi api) async {
      final h = await pumpServer(t, api);
      await h.push('/chat/cv-1');
      return h;
    }

    Future<void> send(WidgetTester t, String text) async {
      await t.enterText(composerField(), text);
      await t.pump();
      await t.tap(tooltip('Send message'));
      await t.pumpAndSettle();
    }

    testWidgets('your saved messages load; sending saves yours first, then asks the server to reply', (t) async {
      final api = world();
      api.onStream = (fn, body) => script([
            ('start', {
              'userNote': _userNote,
              'relationship': snapshot(),
              'usage': {'modelId': 'ember', 'used': 1, 'limit': 30},
            }),
            ('delta', {'text': '*Vesper studies you.* '}),
            ('delta', {'text': '"Your word."'}),
            ('done', {
              'text': '*Vesper studies you.* "Your word."',
              'note': {'text': 'Trust grew a little', 'story': 'Something shifted.', 'entryId': 'e-reply'},
              'relationship': snapshot(),
            }),
          ]);
      final h = await openChat(t, api);
      expect(find.text('The lamp is lit.'), findsOneWidget);

      await send(t, 'I promise I will keep your secret, you have my word.');

      // order of events: your message is saved, THEN the server is asked
      final saved = api.log.indexOf('upsert messages');
      final asked = api.log.indexOf('stream chat_turn');
      expect(saved, greaterThanOrEqualTo(0));
      expect(asked, greaterThan(saved));
      final userRow = api.table('messages').firstWhere((r) => r['role'] == 'user');
      expect((userRow['alts'] as List).single, 'I promise I will keep your secret, you have my word.');

      // what was sent: ids and preferences only
      final body = api.streamBodies.single;
      expect(body['conversationId'], 'cv-1');
      expect(body['personaId'], 'p-me');
      expect(body['modelId'], 'ember');
      expect(body['userMessageId'], userRow['id']);
      expect(body.containsKey('messages'), isFalse);
      expect(body.containsKey('prompt'), isFalse);

      // the reply and the notes are on screen
      expect(find.textContaining('Your word.'), findsWidgets);
      expect(find.text('Trust grew · Why?'), findsOneWidget);
      expect(find.text('Trust grew a little · Why?'), findsOneWidget);

      // the server's count of free replies replaced ours
      expect(h.container.read(modelUsageProvider)['ember'], 29);
      // and the relationship the server sent is what the app shows
      expect(h.container.read(relationshipsProvider).values.single.id, 'rel-1');
      expect(api.log.where((l) => l == 'invoke apply_correction'), isEmpty, reason: 'no separate calls to judge the turn');

      await t.pump(const Duration(seconds: 2)); // let the saving of the reply finish
      final aiRows = api.table('messages').where((r) => r['role'] == 'ai').toList();
      expect(aiRows, hasLength(2));
      expect((aiRows.last['alts'] as List).single, contains('Your word.'));
      expect((aiRows.last['notes'] as Map)['0']['text'], 'Trust grew a little');
    });

    testWidgets('tapping “Why?” opens the journal on that entry', (t) async {
      final api = world();
      api.onStream = (fn, body) => script([
            ('start', {'userNote': {..._userNote, 'entryId': 'e3'}, 'relationship': snapshot()}),
            ('done', {'text': 'Fine.', 'note': null, 'relationship': snapshot()}),
          ]);
      await openChat(t, api);
      await send(t, 'I promise I will keep your secret, you have my word.');
      await t.tapAndSettle(find.text('Trust grew · Why?'));
      expect(find.text('Relationship journal'), findsOneWidget);
      expect(find.text('Why it changed'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('no free replies left: a card says so, your message stays, and the count shows zero', (t) async {
      final api = world();
      api.onStream = (fn, body) => Stream.error(BackendException(429, 'model_limit', 'No free replies left on this model today.', {
            'userNote': _userNote,
            'relationship': snapshot(),
          }));
      final h = await openChat(t, api);
      await send(t, 'I promise I will keep your secret, you have my word.');
      expect(find.text('Ember has used today’s free replies'), findsOneWidget);
      expect(find.text('Switch model'), findsOneWidget);
      expect(find.textContaining('I promise I will keep your secret'), findsOneWidget);
      expect(h.container.read(modelUsageProvider)['ember'], 0);
      expect(find.text('Trust grew · Why?'), findsOneWidget, reason: 'what your message did still shows');
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a model problem on the server is a card with Try again; trying again asks for the same message', (t) async {
      final api = world();
      var calls = 0;
      api.onStream = (fn, body) {
        calls++;
        return calls == 1
            ? script([('start', {'userNote': _userNote, 'relationship': snapshot()}), ('error', {'code': 'empty_reply', 'message': 'The model did not write anything.'})])
            : script([('start', {'relationship': snapshot()}), ('done', {'text': 'There you are.', 'relationship': snapshot()})]);
      };
      await openChat(t, api);
      await send(t, 'I promise I will keep your secret, you have my word.');
      expect(find.text('The reply didn’t come through'), findsOneWidget);
      await t.tapAndSettle(find.text('Try again'));
      expect(find.text('There you are.'), findsOneWidget);
      expect(api.streamBodies[1]['userMessageId'], api.streamBodies[0]['userMessageId'],
          reason: 'the server counts your message once, however often it is asked');
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('an unanswered message of yours can be sent again from its menu', (t) async {
      final api = world();
      var calls = 0;
      api.onStream = (fn, body) {
        calls++;
        return calls == 1
            ? script([('start', {'relationship': snapshot()}), ('error', {'code': 'model_error', 'message': 'The model had a problem.'})])
            : script([('start', {'relationship': snapshot()}), ('done', {'text': 'There you are.', 'relationship': snapshot()})]);
      };
      await openChat(t, api);
      await send(t, 'Hello there, are you awake?');
      expect(find.text('The reply didn’t come through'), findsOneWidget);
      await t.tapAndSettle(tooltip('More options for your message').last);
      await t.tapAndSettle(find.text('Send again'));
      expect(find.text('There you are.'), findsOneWidget);
      expect(api.streamBodies[1]['userMessageId'], api.streamBodies[0]['userMessageId']);
      // once it has a reply, the option is gone
      await t.tapAndSettle(tooltip('More options for your message').last);
      expect(find.text('Send again'), findsNothing);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('offline: “Can’t reach Hearth” and your message is kept', (t) async {
      final api = world();
      final h = await openChat(t, api);
      api.offline = true;
      await send(t, 'Are you there?');
      expect(find.text('Can’t reach Hearth right now'), findsOneWidget);
      expect(find.text('Are you there?'), findsOneWidget);
      expect(h.container.read(modelUsageProvider)['ember'], isNull, reason: 'no free reply was spent locally');
      api.offline = false;
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('deleting a chat removes it from your account and reloads the relationship', (t) async {
      final api = world();
      final h = await openChat(t, api);
      await h.container.read(relationshipsProvider.notifier).ensure('c-vesper');
      api.log.clear();
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Delete chat…'));
      await t.tapAndSettle(find.text('Delete chat'));
      expect(api.table('conversations'), isEmpty);
      expect(api.log, contains('rpc ensure_relationship'), reason: 'the events from that chat are marked, so it reloads');
    });
  });

  group('refreshing', () {
    testWidgets('the refresh button brings in what changed on another device', (t) async {
      final api = world();
      await pumpServer(t, api);
      expect(find.text('Jun Okafor'), findsNothing);
      // another device adds a character
      api.table('characters').add({
        ...characterToRow(
          vesperForDebug.copyWith(id: 'c-jun', name: 'Jun Okafor', first: 'Jun', initial: 'J'),
          userId: 'user-1',
        ),
        'created_at': '2026-02-01',
      });
      await t.tapAndSettle(tooltip('Refresh'));
      expect(find.text('Jun Okafor'), findsWidgets);
    });

    testWidgets('pulling the list down refreshes it', (t) async {
      final api = world();
      await pumpServer(t, api);
      api.table('characters').add({
        ...characterToRow(
          vesperForDebug.copyWith(id: 'c-jun', name: 'Jun Okafor', first: 'Jun', initial: 'J'),
          userId: 'user-1',
        ),
        'created_at': '2026-02-01',
      });
      await t.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(find.text('Jun Okafor'), findsWidgets);
    });

    testWidgets('opening a chat shows messages added from another device', (t) async {
      final api = world();
      final h = await pumpServer(t, api);
      // the phone continued the chat after this device loaded it
      api.table('messages').addAll([
        {
          'id': 'm-user-2',
          'conversation_id': 'cv-1',
          'user_id': 'user-1',
          'role': 'user',
          'alts': ['Sent from my phone.'],
          'alt_index': 0,
          'notes': {},
          'seq': 2,
        },
        {
          'id': 'm-ai-2',
          'conversation_id': 'cv-1',
          'user_id': 'user-1',
          'role': 'ai',
          'alts': ['Heard on the other device.'],
          'alt_index': 0,
          'notes': {},
          'seq': 3,
        },
      ]);
      await h.push('/chat/cv-1');
      expect(find.text('Heard on the other device.'), findsOneWidget);
      expect(find.text('Sent from my phone.'), findsOneWidget);
    });

    testWidgets('refreshing keeps what you just typed: waiting changes are saved first', (t) async {
      final api = world();
      final h = await pumpServer(t, api);
      await h.push('/chat/cv-1');
      await t.enterText(find.descendant(of: find.byType(Composer), matching: find.byType(TextField)), 'Draft?');
      api.onStream = (fn, body) => script([
            ('start', {'relationship': snapshot()}),
            ('done', {'text': 'Fine.', 'relationship': snapshot()}),
          ]);
      await t.pump();
      await t.tap(tooltip('Send message'));
      await t.pumpAndSettle();
      await h.go('/characters');
      await t.tapAndSettle(tooltip('Refresh'));
      // the message was written to the server before reloading, so it is still there
      expect(api.table('messages').any((r) => (r['alts'] as List).contains('Draft?')), isTrue);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a failed refresh says so', (t) async {
      final api = world();
      await pumpServer(t, api);
      api.offline = true;
      await t.tapAndSettle(tooltip('Refresh'));
      expect(find.text('Couldn’t refresh. Check your connection.'), findsOneWidget);
    });
  });

  group('archive and delete with a server', () {
    testWidgets('archiving writes to your account, and deleting a character removes it and its chats', (t) async {
      final api = world();
      await pumpServer(t, api);
      await t.scrollUntilVisible(tooltip('More options for Vesper'), 300, scrollable: find.byType(Scrollable).first);
      await t.tapAndSettle(tooltip('More options for Vesper'));
      await t.tapAndSettle(find.text('Archive'));
      expect(api.table('characters').single['archived'], isTrue);

      await t.pump(const Duration(seconds: 7));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Archived (1)'), 300, scrollable: find.byType(Scrollable).first);
      await t.tapAndSettle(find.text('Archived (1)'));
      await t.scrollUntilVisible(tooltip('More options for Vesper'), 300, scrollable: find.byType(Scrollable).first);
      await t.tapAndSettle(tooltip('More options for Vesper'));
      await t.tapAndSettle(find.text('Delete character…'));
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Delete'));
      expect(api.table('characters'), isEmpty);
      expect(api.table('conversations'), isEmpty, reason: 'their chats go with them');
      await t.pump(const Duration(seconds: 7));
    });
  });

  group('the journal with a server', () {
    testWidgets('shows the server’s relationship and every change is a request, not a computation', (t) async {
      final api = world();
      final h = await pumpServer(t, api);
      await h.push('/characters/c-vesper/relationship');
      expect(find.text('Relationship journal'), findsOneWidget);
      expect(find.text('You & Vesper · Standalone story'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Fast'), 300, scrollable: find.byType(Scrollable).first);
      await t.tapAndSettle(find.text('Fast'));
      expect(api.invokeBodies.last, {'action': 'set_pacing', 'relationshipId': 'rel-1', 'pacing': 'fast'});
    });
  });
}
