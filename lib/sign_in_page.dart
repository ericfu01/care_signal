import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_error_support.dart';
import 'family_repository.dart';
import 'saved_login_email.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _sendingResetEmail = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final email = await loadRememberedLoginEmail();
      if (!mounted) return;
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }
    } catch (e, st) {
      debugPrint('[CareSignal][SignIn] loadRememberedLoginEmail failed: $e');
      debugPrint('$st');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _profilePhotoUrl() {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL?.trim();
    if (photoUrl == null || photoUrl.isEmpty) return null;
    return photoUrl;
  }

  /// Local calendar date `yyyy-MM-dd` for [lastSignInDate] alongside server [lastSignInAt].
  static String _formatLocalDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _recordLastSignIn(User user) async {
    final now = DateTime.now();
    try {
      final profile = await FamilyRepository.instance.getUserProfile(user.uid);
      final displayName = profile?.displayName ??
          user.displayName?.trim() ??
          (user.email?.split('@').first ?? 'Member');
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'lastSignInAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'lastSignInDate': _formatLocalDate(now),
          if (profile?.displayName == null || profile!.displayName.isEmpty)
            'displayName': displayName,
          if (user.email != null) 'email': user.email,
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('[CareSignal][SignIn] last sign-in Firestore write failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> _signIn() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _statusMessage = 'Enter email and password.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _statusMessage = 'Signing in...';
    });
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw TimeoutException('Firebase sign-in timed out after 45s');
            },
          );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _recordLastSignIn(user);
      }
      try {
        await saveRememberedLoginEmail(email);
      } catch (e, st) {
        debugPrint(
          '[CareSignal][SignIn] saveRememberedLoginEmail failed (sign-in still ok): $e',
        );
        debugPrint('$st');
      }
      if (!mounted) return;
      // AuthGate listens to auth state and routes to the correct home.
    } on TimeoutException catch (e, st) {
      debugPrint('[CareSignal][SignIn] signIn timeout: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _statusMessage = 'Sign-in timed out. Check your network.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in timed out. Check your network and try again.'),
        ),
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '[CareSignal][SignIn] signIn FirebaseAuthException '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      if (!mounted) return;
      setState(
        () => _statusMessage = e.message ?? 'Sign in failed (${e.code}).',
      );
      showFirebaseAuthExceptionSnackBar(context, e, isSignUp: false);
    } catch (e, st) {
      debugPrint('[CareSignal][SignIn] signIn unexpected error: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _statusMessage = 'Something went wrong: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _sendingResetEmail = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '[CareSignal][SignIn] sendPasswordResetEmail FirebaseAuthException '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      if (!mounted) return;
      showFirebaseAuthExceptionSnackBar(context, e, isSignUp: false);
    } catch (e, st) {
      debugPrint('[CareSignal][SignIn] sendPasswordResetEmail unexpected: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send reset email: $e')));
    } finally {
      if (mounted) setState(() => _sendingResetEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = _profilePhotoUrl();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Sign In')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: profilePhotoUrl != null
                    ? NetworkImage(profilePhotoUrl)
                    : null,
                child: profilePhotoUrl == null
                    ? const Icon(Icons.person, size: 34)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                enabled: !_loading,
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading || _sendingResetEmail
                      ? null
                      : _resetPassword,
                  child: _sendingResetEmail
                      ? const Text('Sending...')
                      : const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
