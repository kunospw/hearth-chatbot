import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/widgets/composer.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/library/data/library_repository.dart';

import 'support/harness.dart';

Finder composerField() =>
    find.descendant(of: find.byType(Composer), matching: find.byType(TextField));

void main() {
  testWidgets('the persona chip switches who you play as and the chat remembers it', (t) async {
    final h = await pumpHearth(t);
    await h.push('/chat/c1');
    await h.container.read(personasProvider.future);
    await t.pumpAndSettle();
    final chip = find.textContaining('As ');
    expect(chip, findsOneWidget);
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(find.text('Play this chat as'), findsOneWidget);
    await t.tap(find.text('Just me'));
    await t.pumpAndSettle();
    expect(h.container.read(conversationProvider('c1'))!.personaId, 'me');
    expect(h.container.read(activePersonaIdProvider), 'me');
    expect(find.text('As Just me'), findsOneWidget);
  });

  testWidgets('suggested replies fill the message box and send nothing', (t) async {
    final h = await pumpHearth(t);
    await h.push('/chat/c1');
    final before = h.container.read(conversationProvider('c1'))!.messages.length;
    await t.tap(find.text('Suggest replies'));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('New ideas'), findsOneWidget);
    await t.tap(find.textContaining('What are you not telling me'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(composerField()).controller!.text, contains('not telling me'));
    expect(h.container.read(conversationProvider('c1'))!.messages.length, before);
    expect(find.text('Suggest replies'), findsOneWidget);
  });

  testWidgets('the tools row keeps its height whatever it shows', (t) async {
    final h = await pumpHearth(t);
    await h.push('/chat/c1');
    final y0 = t.getTopLeft(find.byType(Composer)).dy;
    await t.tap(find.text('Suggest replies'));
    await t.pump();
    expect(find.text('Thinking of ideas…'), findsOneWidget);
    expect(t.getTopLeft(find.byType(Composer)).dy, closeTo(y0, 0.5));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
  });
}
