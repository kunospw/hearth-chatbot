import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Who is signed in. Only what the app shows.
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

enum SignUpResult { signedIn, needsConfirmation }

/// Why signing in or up did not work, in words a person can act on.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthService {
  AuthUser? get current;
  Stream<AuthUser?> get changes;
  Future<void> signIn(String email, String password);
  Future<SignUpResult> signUp(String email, String password);
  Future<void> signOut();
}

/// Supabase email + password. Passwords go straight to Supabase Auth; the app
/// never stores them.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService([sb.SupabaseClient? client])
    : _auth = (client ?? sb.Supabase.instance.client).auth;

  final sb.GoTrueClient _auth;

  static AuthUser? _user(sb.User? u) =>
      u == null ? null : AuthUser(id: u.id, email: u.email ?? '');

  @override
  AuthUser? get current => _user(_auth.currentUser);

  @override
  Stream<AuthUser?> get changes =>
      _auth.onAuthStateChange.map((s) => _user(s.session?.user));

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on sb.AuthException catch (e) {
      throw AuthFailure(_friendly(e, signUp: false));
    } catch (_) {
      throw const AuthFailure(
        'We can’t reach the server. Check your connection and try again.',
      );
    }
  }

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    try {
      final r = await _auth.signUp(email: email.trim(), password: password);
      return r.session == null
          ? SignUpResult.needsConfirmation
          : SignUpResult.signedIn;
    } on sb.AuthException catch (e) {
      throw AuthFailure(_friendly(e, signUp: true));
    } catch (_) {
      throw const AuthFailure(
        'We can’t reach the server. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static String _friendly(sb.AuthException e, {required bool signUp}) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'That email or password isn’t right.';
    }
    if (m.contains('already registered') ||
        m.contains('already been registered')) {
      return 'There’s already an account with that email. Try signing in.';
    }
    if (m.contains('password') &&
        (m.contains('at least') || m.contains('weak') || m.contains('short'))) {
      return 'Choose a longer password (at least 8 characters).';
    }
    if (m.contains('not confirmed')) {
      return 'Confirm your email first. We sent you a link.';
    }
    if (m.contains('rate') || m.contains('too many')) {
      return 'Too many tries. Wait a minute and try again.';
    }
    if (m.contains('valid email') || m.contains('invalid email')) {
      return 'That doesn’t look like an email address.';
    }
    return signUp
        ? 'We couldn’t create the account. Try again.'
        : 'We couldn’t sign you in. Try again.';
  }
}
