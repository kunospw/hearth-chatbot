import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/util/roleplay_parser.dart';

RoleSegment n(String s) => RoleSegment(RoleKind.narration, s);
RoleSegment a(String s) => RoleSegment(RoleKind.action, s);
RoleSegment d(String s) => RoleSegment(RoleKind.dialogue, s);

void main() {
  test('splits actions, dialogue and narration', () {
    final p = parseRoleplay('*She nods.* "Come in." Fog rolls.');
    expect(p, hasLength(1));
    expect(p.first, [a('She nods.'), n(' '), d('“Come in.”'), n(' Fog rolls.')]);
  });

  test('paragraphs split on newlines and blanks are dropped', () {
    final p = parseRoleplay('*One.*\n\n\n"Two."\n  \nThree');
    expect(p.map((x) => x.first.kind),
        [RoleKind.action, RoleKind.dialogue, RoleKind.narration]);
  });

  group('half-streamed text', () {
    test('unclosed action runs to the end', () {
      expect(parseRoleplay('*She steps asi').single, [a('She steps asi')]);
    });

    test('unclosed dialogue runs to the end with an opening quote', () {
      expect(parseRoleplay('She said "Come in, th').single,
          [n('She said '), d('“Come in, th')]);
    });

    test('a lone marker produces nothing and never throws', () {
      expect(parseRoleplay('*'), isEmpty);
      expect(parseRoleplay('"'), [
        [d('“')]
      ]);
      expect(parseRoleplay(''), isEmpty);
    });

    test('every prefix of a real reply parses without error', () {
      const reply =
          '*Vesper sets the kettle down.*\n\n"They come in on the north tide." *She lays the top one on the table.* "Seven so far."';
      for (var i = 0; i <= reply.length; i++) {
        expect(() => parseRoleplay(reply.substring(0, i)), returnsNormally);
      }
    });

    test('text is preserved across all prefixes (no characters lost)', () {
      const reply = '*A.* "B." C';
      final full = parseRoleplay(reply).expand((s) => s).map((s) => s.text).join();
      expect(full.replaceAll(RegExp('[“”]'), ''), 'A. B. C');
    });
  });

  test('action inside dialogue resumes dialogue afterwards', () {
    expect(parseRoleplay('"Hello *waves* world"').single,
        [d('“Hello '), a('waves'), d(' world”')]);
  });

  test('a quote inside an action stays part of the action', () {
    expect(parseRoleplay('*She mutters "no" and leaves.*').single,
        [a('She mutters "no" and leaves.')]);
  });

  test('typographic quotes are treated as dialogue', () {
    expect(parseRoleplay('“Hi.”').single, [d('“Hi.”')]);
  });

  test('empty action markers are dropped', () {
    expect(parseRoleplay('A ** B').single, [n('A  B')]);
  });

  test('stripRoleplay removes markup and collapses whitespace', () {
    expect(stripRoleplay('*Hi*  there\n\n"you"'), 'Hi there "you"');
  });
}
