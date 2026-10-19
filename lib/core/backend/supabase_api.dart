import 'dart:async';
import 'dart:convert';

import 'package:fetch_client/fetch_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'backend_api.dart';
import 'backend_config.dart';

/// [BackendApi] on top of supabase_flutter. The only file that knows Supabase.
///
/// The app only ever holds the project URL and the anon key plus the signed-in
/// user's own session; what that user can read or change is decided by
/// row-level security in the database, and the model is only reachable through
/// the edge functions.
class SupabaseBackendApi implements BackendApi {
  SupabaseBackendApi(
    this.config, {
    SupabaseClient? client,
    http.Client? httpClient,
  }) : _client = client ?? Supabase.instance.client,
       // On the web the plain http client buffers the whole answer; fetch can stream it.
       _http =
           httpClient ??
           (kIsWeb ? FetchClient(mode: RequestMode.cors) : http.Client());

  final BackendConfig config;
  final SupabaseClient _client;
  final http.Client _http;

  @override
  String? get userId => _client.auth.currentUser?.id;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on BackendException {
      rethrow;
    } on OfflineBackendException {
      rethrow;
    } on PostgrestException catch (e) {
      throw BackendException(
        int.tryParse(e.code ?? '') ?? 400,
        e.code ?? 'db_error',
        e.message,
      );
    } on FunctionException catch (e) {
      final d = e.details;
      final err = d is Map ? d['error'] : null;
      throw BackendException(
        e.status,
        err is Map ? '${err['code']}' : 'server_error',
        err is Map ? '${err['message']}' : 'Something went wrong.',
        d is Map<String, dynamic> ? d : const {},
      );
    } on AuthException catch (e) {
      throw BackendException(
        e.statusCode == null ? 401 : int.tryParse(e.statusCode!) ?? 401,
        'auth',
        e.message,
      );
    } on TimeoutException {
      throw const OfflineBackendException();
    } catch (e) {
      if (_isNetworkError(e)) throw const OfflineBackendException();
      rethrow;
    }
  }

  static bool _isNetworkError(Object e) {
    if (e is http.ClientException) return true;
    final t = e.runtimeType.toString();
    return t.contains('SocketException') ||
        t.contains('HandshakeException') ||
        t.contains('Network');
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
    Map<String, Object> eq = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) => _guard(() async {
    var filter = _client.from(table).select(columns);
    for (final e in eq.entries) {
      filter = filter.eq(e.key, e.value);
    }
    PostgrestTransformBuilder<List<Map<String, dynamic>>> q = filter;
    if (orderBy != null) q = q.order(orderBy, ascending: ascending);
    if (limit != null) q = q.limit(limit);
    return await q;
  });

  @override
  Future<void> upsert(String table, Object rows, {String? onConflict}) =>
      _guard(() async {
        await _client.from(table).upsert(rows, onConflict: onConflict);
      });

  @override
  Future<void> update(
    String table,
    Map<String, Object?> values, {
    required Map<String, Object> eq,
  }) => _guard(() async {
    var q = _client.from(table).update(values);
    for (final e in eq.entries) {
      q = q.eq(e.key, e.value);
    }
    await q;
  });

  @override
  Future<void> delete(String table, {required Map<String, Object> eq}) =>
      _guard(() async {
        var q = _client.from(table).delete();
        for (final e in eq.entries) {
          q = q.eq(e.key, e.value);
        }
        await q;
      });

  @override
  Future<dynamic> rpc(String fn, [Map<String, Object?> params = const {}]) =>
      _guard(() async => await _client.rpc(fn, params: params));

  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> body) =>
      _guard(() async {
        final res = await _client.functions.invoke(fn, body: body);
        final d = res.data;
        return d is Map<String, dynamic> ? d : <String, dynamic>{};
      });

  Future<String?> _freshToken() async {
    var session = _client.auth.currentSession;
    if (session == null) return null;
    final exp = session.expiresAt;
    if (exp != null &&
        exp * 1000 - DateTime.now().millisecondsSinceEpoch < 60000) {
      session = (await _client.auth.refreshSession()).session ?? session;
    }
    return session.accessToken;
  }

  /// Cancelling the stream aborts the request, so the server sees the
  /// connection close (and stops the model) even while it is still thinking.
  @override
  Stream<SseEvent> stream(String fn, Map<String, Object?> body) {
    final abort = Completer<void>();
    StreamSubscription<SseEvent>? sub;
    late final StreamController<SseEvent> out;

    void fail(Object e) {
      if (out.isClosed) return;
      out.addError(
        e is BackendException || e is OfflineBackendException
            ? e
            : (_isNetworkError(e) ? const OfflineBackendException() : e),
      );
      out.close();
    }

    Future<void> start() async {
      try {
        final token = await _guard(_freshToken);
        if (token == null) {
          throw const BackendException(401, 'unauthorized', 'Sign in first.');
        }
        if (abort.isCompleted) return;
        final req =
            http.AbortableRequest(
                'POST',
                Uri.parse('${config.url}/functions/v1/$fn'),
                abortTrigger: abort.future,
              )
              ..headers.addAll({
                'content-type': 'application/json',
                'authorization': 'Bearer $token',
                'apikey': config.anonKey,
                'accept': 'text/event-stream',
              })
              ..body = jsonEncode(body);
        final res = await _http.send(req);
        if (abort.isCompleted) return;
        if (res.statusCode != 200) {
          final text = await res.stream.bytesToString();
          Map<String, dynamic> j = const {};
          try {
            final d = jsonDecode(text);
            if (d is Map<String, dynamic>) j = d;
          } catch (_) {}
          final err = j['error'];
          throw BackendException(
            res.statusCode,
            err is Map ? '${err['code']}' : 'server_error',
            err is Map ? '${err['message']}' : 'Something went wrong.',
            j,
          );
        }
        sub = parseSse(res.stream).listen(
          out.add,
          onError: fail,
          onDone: () {
            if (!out.isClosed) out.close();
          },
        );
      } catch (e) {
        fail(e);
      }
    }

    out = StreamController<SseEvent>(
      onListen: () => unawaited(start()),
      onCancel: () {
        if (!abort.isCompleted) abort.complete();
        unawaited(sub?.cancel());
      },
    );
    return out.stream;
  }

  @override
  Future<String> uploadPortrait(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) => _guard(() async {
    final uid = userId;
    if (uid == null) {
      throw const BackendException(401, 'unauthorized', 'Sign in first.');
    }
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final path = '$uid/${const Uuid().v4()}.$ext';
    await _client.storage
        .from('portraits')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _client.storage.from('portraits').getPublicUrl(path);
  });
}
