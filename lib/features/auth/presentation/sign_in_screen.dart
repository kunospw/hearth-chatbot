import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/hearth_logo.dart';
import '../data/auth_providers.dart';
import '../data/auth_service.dart';

/// Email and password. Signing in is the only thing this screen does; the rest
/// of the app appears behind it ([AuthGate]).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid => _email.text.contains('@') && _password.text.length >= 6;

  Future<void> _submit() async {
    if (_busy || !_valid) return;
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_creating) {
        final r = await service.signUp(_email.text, _password.text);
        if (r == SignUpResult.needsConfirmation && mounted) {
          setState(() {
            _creating = false;
            _info =
                'Almost there. We sent a link to ${_email.text.trim()}. Open it, then sign in here.';
          });
        }
      } else {
        await service.signIn(_email.text, _password.text);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Reading.storyMaxWidth * 0.6,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: HearthLogo(size: Sizes.logoSplash)),
                    const SizedBox(height: Space.xl),
                    Text(
                      _creating ? 'Create your account' : 'Welcome back',
                      style: t.display,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      _creating
                          ? 'Your characters and stories are saved to your account.'
                          : 'Sign in to pick up your stories where you left them.',
                      style: t.body.copyWith(color: c.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.xl),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      style: t.body,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: [
                        _creating
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                      style: t.body,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          constraints: const BoxConstraints(
                            minWidth: Hit.inline,
                            minHeight: Hit.inline,
                          ),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: t.body.copyWith(color: c.danger),
                        ),
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: Space.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _info!,
                          style: t.body.copyWith(color: c.primaryInk),
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.lg),
                    FilledButton(
                      onPressed: _valid && !_busy ? _submit : null,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: Space.xl,
                              child: CircularProgressIndicator(
                                strokeWidth: Sizes.stroke,
                              ),
                            )
                          : Text(_creating ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: Space.sm),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(Hit.primary, Hit.primary),
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creating = !_creating;
                              _error = null;
                              _info = null;
                            }),
                      child: Text(
                        _creating
                            ? 'I already have an account'
                            : 'New here? Create an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [child] once signed in; the sign-in screen before that. With no server
/// (sample-data mode) it just shows [child].
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(needsSignInProvider)) return child;
    // Its own Navigator: text fields need an Overlay for selection handles, and
    // the app's Navigator is below this widget.
    return Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
    );
  }
}
