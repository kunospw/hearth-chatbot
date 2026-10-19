import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// The few things the app asks of the server, as plain Dart. Repositories use
/// this instead of supabase_flutter directly, so they can be tested with
/// an in-memory fake and the Supabase details stay in one file
/// ([SupabaseBackendApi]).
abstract interface class BackendApi {
  /// The signed-in user (null when signed out).
  String? get userId;

  /// Rows of [table] you are allowed to see. [eq] filters by equality.
  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
    Map<String, Object> eq = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
  });

  /// Inserts rows, or replaces the ones with the same key.
  Future<void> upsert(String table, Object rows, {String? onConflict});

  Future<void> update(
    String table,
    Map<String, Object?> values, {
    required Map<String, Object> eq,
  });

  Future<void> delete(String table, {required Map<String, Object> eq});

  /// A database function (relationship snapshot, ensure_relationship…).
  Future<dynamic> rpc(String fn, [Map<String, Object?> params = const {}]);

  /// An edge function that answers with one JSON object.
  /// Throws [BackendException] for an error answer and [OfflineBackendException] with no connection.
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> body);

  /// An edge function that answers with server-sent events. Cancel the
  /// subscription to stop it.
  Stream<SseEvent> stream(String fn, Map<String, Object?> body);

  /// Stores a picture and returns the address to load it from.
  Future<String> uploadPortrait(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  });
}

/// The server said no (or something went wrong there).
class BackendException implements Exception {
  const BackendException(
    this.status,
    this.code,
    this.message, [
    this.body = const {},
  ]);

  final int status;

  /// A short machine word: model_limit, model_busy, not_found, …
  final String code;
  final String message;

  /// The whole error answer, which can carry more (the relationship, the note).
  final Map<String, dynamic> body;

  @override
  String toString() => 'BackendException($status, $code, $message)';
}

/// No connection to the server.
class OfflineBackendException implements Exception {
  const OfflineBackendException();

  @override
  String toString() => 'OfflineBackendException';
}

class SseEvent {
  const SseEvent(this.event, this.data);

  final String event;
  final Map<String, dynamic> data;

  @override
  String toString() => 'SseEvent($event, $data)';
}

/// Reads a server-sent-event byte stream. Events are separated by a blank
/// line; only `event:` and `data:` lines matter. Bad JSON is skipped.
///
/// Built on a controller rather than an `async*` generator so that cancelling
/// reaches the source at once (a generator only notices at its next `yield`).
Stream<SseEvent> parseSse(Stream<List<int>> bytes) {
  StreamSubscription<String>? sub;
  late final StreamController<SseEvent> out;
  out = StreamController<SseEvent>(
    onListen: () {
      var buffer = '';
      sub = bytes
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (chunk) {
              buffer += chunk.replaceAll('\r\n', '\n');
              int end;
              while ((end = buffer.indexOf('\n\n')) >= 0) {
                final block = buffer.substring(0, end);
                buffer = buffer.substring(end + 2);
                final e = _readBlock(block);
                if (e != null) out.add(e);
              }
            },
            onError: out.addError,
            onDone: () {
              final tail = _readBlock(buffer.trim());
              if (tail != null) out.add(tail);
              out.close();
            },
          );
    },
    onCancel: () {
      unawaited(sub?.cancel());
    },
  );
  return out.stream;
}

SseEvent? _readBlock(String block) {
  if (block.trim().isEmpty) return null;
  var event = 'message';
  final data = StringBuffer();
  for (final line in block.split('\n')) {
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.write(line.substring(5).trim());
    }
  }
  try {
    final j = data.isEmpty ? <String, dynamic>{} : jsonDecode(data.toString());
    return SseEvent(event, j is Map<String, dynamic> ? j : {'value': j});
  } catch (_) {
    return null;
  }
}
