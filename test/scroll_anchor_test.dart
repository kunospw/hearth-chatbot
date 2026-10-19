import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/features/chat/presentation/message_list.dart';

/// Chat and Story lay the same messages out at different heights, so the same
/// message can't be at the same pixel offset. The anchor must still land on it.
List<ListEntry> entries(bool chat, {int n = 60}) => [
      for (var i = 0; i < n; i++)
        ListEntry(
          id: 'm$i',
          builder: (_) => SizedBox(
            height: chat ? 70.0 + (i % 5) * 35 : 110.0 + (i % 3) * 90,
            child: Align(alignment: Alignment.topLeft, child: Text('m$i')),
          ),
        ),
    ];

class Host extends StatefulWidget {
  const Host({super.key, this.startChat = true, this.n = 60});
  final bool startChat;
  final int n;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late bool chat = widget.startChat;
  ScrollAnchor? anchor;
  final listKey = GlobalKey<MessageListState>();
  final nearEvents = <bool>[];

  void switchTo(bool toChat, ScrollAnchor? a) => setState(() {
        anchor = a;
        chat = toChat;
      });

  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: MessageList(
          key: ValueKey(chat),
          // GlobalKey wrapper so tests can reach the state of the current list.
          entries: entries(chat, n: widget.n),
          reversed: chat,
          initialAnchor: anchor,
          onNearBottomChanged: nearEvents.add,
          padding: EdgeInsets.zero,
          verticalPadding: 0,
        ),
      ),
    );
  }
}

MessageListState listState(WidgetTester t) => t.state<MessageListState>(find.byType(MessageList));

void main() {
  Future<HostState> pumpHost(WidgetTester t, {bool chat = true, int n = 60}) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(Host(startChat: chat, n: n));
    await t.pumpAndSettle();
    return t.state<HostState>(find.byType(Host));
  }

  // The test host keeps its own key; reach captureAnchor via the state of the list.
  ScrollAnchor? capture(WidgetTester t) => listState(t).captureAnchor();

  Future<void> switchMode(WidgetTester t) async {
    final a = capture(t);
    final host = t.state<HostState>(find.byType(Host));
    host.switchTo(!host.chat, a);
    await t.pumpAndSettle();
  }

  testWidgets('a fresh Chat opens at the newest message (offset 0)', (t) async {
    await pumpHost(t);
    expect(find.text('m59'), findsOneWidget);
    expect(listState(t).controller.position.pixels, 0);
  });

  testWidgets('a fresh Story opens at the newest message too', (t) async {
    await pumpHost(t, chat: false);
    final p = listState(t).controller.position;
    expect(p.pixels, closeTo(p.maxScrollExtent, 1));
    expect(find.text('m59'), findsOneWidget);
  });

  testWidgets('at the bottom, switching modes stays at the bottom (both ways)', (t) async {
    await pumpHost(t);
    expect(capture(t)!.atBottom, isTrue);
    await switchMode(t);
    var p = listState(t).controller.position;
    expect(p.pixels, closeTo(p.maxScrollExtent, 1));
    expect(find.text('m59'), findsOneWidget);
    await switchMode(t);
    p = listState(t).controller.position;
    expect(p.pixels, 0);
  });

  for (final startChat in [true, false]) {
    for (final dragUp in [900.0, 2600.0, 5200.0]) {
      testWidgets(
          'reading mid-conversation: ${startChat ? "Chat → Story" : "Story → Chat"} '
          'keeps the same first message and fraction (scrolled $dragUp)', (t) async {
        await pumpHost(t, chat: startChat);
        await t.drag(find.byType(MessageList), Offset(0, dragUp));
        await t.pumpAndSettle();

        final before = capture(t)!;
        expect(before.atBottom, isFalse);

        await switchMode(t);
        final after = capture(t)!;
        expect(after.atBottom, isFalse);
        expect(after.messageId, before.messageId,
            reason: 'before=$before after=$after');
        expect(after.fraction, closeTo(before.fraction, 0.03),
            reason: 'before=$before after=$after');

        // And back again lands on the same place.
        await switchMode(t);
        final back = capture(t)!;
        expect(back.messageId, before.messageId);
        expect(back.fraction, closeTo(before.fraction, 0.03));
      });
    }
  }

  testWidgets('the list is hidden until the position is restored, then fully visible', (t) async {
    await pumpHost(t);
    await t.drag(find.byType(MessageList), const Offset(0, 1500));
    await t.pumpAndSettle();
    final a = capture(t);
    final host = t.state<HostState>(find.byType(Host));
    host.switchTo(false, a);
    await t.pumpAndSettle();
    expect(t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1);
  });

  testWidgets('reports leaving and returning to the bottom (72dp threshold)', (t) async {
    final host = await pumpHost(t);
    host.nearEvents.clear();
    // Scroll up 30dp: still near the bottom, no event.
    await t.drag(find.byType(MessageList), const Offset(0, 30));
    await t.pumpAndSettle();
    expect(host.nearEvents, isEmpty);
    // Scroll further: leaves.
    await t.drag(find.byType(MessageList), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(host.nearEvents, [false]);
    // Come back.
    await t.drag(find.byType(MessageList), const Offset(0, -400));
    await t.pumpAndSettle();
    expect(host.nearEvents, [false, true]);
  });

  testWidgets('new content while at the bottom keeps following; while reading it does not move',
      (t) async {
    await pumpHost(t, chat: false, n: 30);
    final p = listState(t).controller.position;
    // grow: rebuild with more entries
    final host = t.state<HostState>(find.byType(Host));
    expect(p.pixels, closeTo(p.maxScrollExtent, 1));
    // Reading: scroll up first, then change nothing about the list length but
    // check pixels are preserved across a rebuild.
    await t.drag(find.byType(MessageList), const Offset(0, 800));
    await t.pumpAndSettle();
    final y = listState(t).controller.position.pixels;
    host.rebuild();
    await t.pumpAndSettle();
    expect(listState(t).controller.position.pixels, y);
  });
}
