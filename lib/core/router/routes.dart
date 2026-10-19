/// Route paths (SPEC §4). Detail screens are pushed full screen with no bottom
/// bar; the three tab roots live inside the shell.
abstract final class Routes {
  static const characters = '/characters';
  static const characterNew = '/characters/new';
  static String character(String id) => '/characters/$id';
  static String characterEdit(String id, {String? draft}) =>
      '/characters/$id/edit${draft == null ? '' : '?draft=$draft'}';

  /// Resume a saved draft of a new character.
  static String draftNew(String draftId) => '/characters/new?draft=$draftId';

  /// [entry] opens the journal with that timeline entry expanded.
  static String relationship(String characterId, {String? entry}) =>
      '/characters/$characterId/relationship${entry == null ? '' : '?entry=$entry'}';

  static const chats = '/chats';
  static String chat(String conversationId) => '/chat/$conversationId';

  /// [tab] is one of `universes`, `memories`, `personas`.
  static String library({String? tab}) =>
      tab == null ? '/library' : '/library?tab=$tab';
  static String universe(String id) => '/universes/$id';
  static String universeMemories(String id) => '/universes/$id/memories';

  static const settings = '/settings';
  static const aiSettings = '/settings/ai';

  /// Debug-only design reference (type scale, colours, theme toggle).
  static const dev = '/dev';
  static const devGallery = '/dev/gallery';
}
