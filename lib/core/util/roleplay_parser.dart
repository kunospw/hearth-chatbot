/// Parsing for roleplay prose: `*actions*`, `"dialogue"` and plain narration.
///
/// Tolerant of half-streamed text: an unclosed `*` or `"` simply runs to the
/// end of the paragraph, so a reply looks right at every moment while it
/// streams in.
library;

enum RoleKind { narration, action, dialogue }

class RoleSegment {
  const RoleSegment(this.kind, this.text);

  final RoleKind kind;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is RoleSegment && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '${kind.name}(${text.replaceAll('\n', r'\n')})';
}

const _openQuote = '“';
const _closeQuote = '”';

/// Splits [text] into paragraphs (on newlines) of styled segments.
///
/// - `*…*` is an action. It can sit inside dialogue; dialogue resumes after it.
/// - `"…"` (or typographic “…”) is dialogue and is shown with typographic quotes.
/// - A `"` inside an action stays part of the action.
List<List<RoleSegment>> parseRoleplay(String text) {
  final paragraphs = <List<RoleSegment>>[];
  for (final raw in text.split(RegExp(r'\n+'))) {
    if (raw.trim().isEmpty) continue;
    final segs = <RoleSegment>[];
    var mode = RoleKind.narration;
    // What to return to when an action ends (narration or dialogue).
    var base = RoleKind.narration;
    final buf = StringBuffer();

    void flush() {
      if (buf.isEmpty) return;
      final s = buf.toString();
      buf.clear();
      // Drop whitespace-only action/dialogue runs from `**` or stray markup.
      if (mode != RoleKind.narration && s.trim().isEmpty) return;
      // Merge with the previous run when markup (e.g. `**`) split one run in two.
      if (segs.isNotEmpty &&
          segs.last.kind == mode &&
          mode != RoleKind.dialogue) {
        segs[segs.length - 1] = RoleSegment(mode, segs.last.text + s);
      } else {
        segs.add(RoleSegment(mode, s));
      }
    }

    for (final ch in raw.split('')) {
      if (ch == '*') {
        flush();
        if (mode == RoleKind.action) {
          mode = base;
        } else {
          base = mode;
          mode = RoleKind.action;
        }
        continue;
      }
      if (mode != RoleKind.action &&
          (ch == '"' || ch == _openQuote || ch == _closeQuote)) {
        if (mode == RoleKind.dialogue) {
          buf.write(_closeQuote);
          flush();
          mode = RoleKind.narration;
          base = RoleKind.narration;
        } else {
          flush();
          mode = RoleKind.dialogue;
          base = RoleKind.dialogue;
          buf.write(_openQuote);
        }
        continue;
      }
      buf.write(ch);
    }
    flush();
    if (segs.isNotEmpty) paragraphs.add(segs);
  }
  return paragraphs;
}

/// Plain one-line preview: markup removed, whitespace collapsed.
String stripRoleplay(String text) =>
    text.replaceAll('*', '').replaceAll(RegExp(r'\s+'), ' ').trim();
