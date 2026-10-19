import 'dart:async';
import 'dart:typed_data';

import 'package:hearth/core/backend/backend_api.dart';
import 'package:hearth/features/auth/data/auth_service.dart';

/// An in-memory server for tests: tables you can read and write, database
/// functions and edge functions you script, and a log of every call.
class FakeBackendApi implements BackendApi {
  FakeBackendApi({this.userId = 'user-1'});

  @override
  String? userId;

  final Map<String, List<Map<String, dynamic>>> tables = {};
  final Map<String, dynamic Function(Map<String, Object?> params)> rpcs = {};
  final Map<String, Map<String, dynamic> Function(Map<String, Object?> body)> invokes = {};
  Stream<SseEvent> Function(String fn, Map<String, Object?> body)? onStream;

  /// Everything the app asked for, in order, as `kind table/fn`.
  final List<String> log = [];
  final List<Map<String, Object?>> streamBodies = [];
  final List<Map<String, Object?>> invokeBodies = [];
  final List<Uint8List> uploads = [];
  bool offline = false;

  List<Map<String, dynamic>> table(String name) => tables.putIfAbsent(name, () => []);

  void _gate() {
    if (offline) throw const OfflineBackendException();
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
    Map<String, Object> eq = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    _gate();
    log.add('select $table');
    var rows = this.table(table).where((r) => eq.entries.every((e) => r[e.key] == e.value)).map((r) => Map<String, dynamic>.from(r)).toList();
    if (orderBy != null) {
      rows.sort((a, b) {
        final x = a[orderBy];
        final y = b[orderBy];
        final c = x is Comparable && y is Comparable ? x.compareTo(y) : 0;
        return ascending ? c : -c;
      });
    }
    if (limit != null && rows.length > limit) rows = rows.sublist(0, limit);
    return rows;
  }

  @override
  Future<void> upsert(String table, Object rows, {String? onConflict}) async {
    _gate();
    log.add('upsert $table');
    final list = rows is List ? rows : [rows];
    final t = this.table(table);
    for (final r in list) {
      final row = Map<String, dynamic>.from(r as Map);
      final i = t.indexWhere((x) => x['id'] == row['id']);
      if (i < 0) {
        t.add(row);
      } else {
        t[i] = {...t[i], ...row};
      }
    }
  }

  @override
  Future<void> update(String table, Map<String, Object?> values, {required Map<String, Object> eq}) async {
    _gate();
    log.add('update $table');
    for (final r in this.table(table)) {
      if (eq.entries.every((e) => r[e.key] == e.value)) r.addAll(values);
    }
  }

  @override
  Future<void> delete(String table, {required Map<String, Object> eq}) async {
    _gate();
    log.add('delete $table');
    this.table(table).removeWhere((r) => eq.entries.every((e) => r[e.key] == e.value));
  }

  @override
  Future<dynamic> rpc(String fn, [Map<String, Object?> params = const {}]) async {
    _gate();
    log.add('rpc $fn');
    final h = rpcs[fn];
    if (h == null) throw BackendException(404, 'not_found', 'no rpc $fn');
    return h(params);
  }

  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> body) async {
    _gate();
    log.add('invoke $fn');
    invokeBodies.add(body);
    final h = invokes[fn];
    if (h == null) throw BackendException(404, 'not_found', 'no function $fn');
    return h(body);
  }

  @override
  Stream<SseEvent> stream(String fn, Map<String, Object?> body) {
    log.add('stream $fn');
    streamBodies.add(body);
    if (offline) return Stream.error(const OfflineBackendException());
    final h = onStream;
    if (h == null) return Stream.error(BackendException(404, 'not_found', 'no stream $fn'));
    return h(fn, body);
  }

  @override
  Future<String> uploadPortrait(Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    _gate();
    uploads.add(bytes);
    return 'https://example.test/portraits/${uploads.length}.jpg';
  }
}

/// Sign-in for tests: accepts one email and password.
class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? signedIn}) : _current = signedIn;

  AuthUser? _current;
  final _changes = StreamController<AuthUser?>.broadcast();
  final List<String> calls = [];
  bool needsConfirmation = false;
  static const goodPassword = 'correct horse';

  @override
  AuthUser? get current => _current;

  @override
  Stream<AuthUser?> get changes => _changes.stream;

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn $email');
    if (password != goodPassword) throw const AuthFailure('That email or password isn’t right.');
    _current = AuthUser(id: 'user-1', email: email);
    _changes.add(_current);
  }

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    calls.add('signUp $email');
    if (needsConfirmation) return SignUpResult.needsConfirmation;
    _current = AuthUser(id: 'user-1', email: email);
    _changes.add(_current);
    return SignUpResult.signedIn;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _current = null;
    _changes.add(null);
  }
}
