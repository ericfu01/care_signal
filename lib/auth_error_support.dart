import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Firebase iOS email/password often fails with [internal-error] when
/// [GoogleService-Info.plist] has no OAuth keys. Enable the Google sign-in
/// provider once in Firebase Console, re-download the plist, then add
/// [REVERSED_CLIENT_ID] under URL Types in Xcode.
void showFirebaseIosAuthSetupDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Fix Firebase on iOS'),
      content: const SingleChildScrollView(
        child: Text(
          'That generic error usually means the native Firebase Auth setup is '
          'incomplete.\n\n'
          '1. Firebase Console → Build → Authentication → Sign-in method: '
          'enable Email/Password.\n'
          '2. On the same page, enable Google (you can still sign in with '
          'email only; this makes Firebase add OAuth client IDs to your '
          'config file).\n'
          '3. Project settings (gear) → Your apps → iOS → Download '
          'GoogleService-Info.plist.\n'
          '4. Replace ios/Runner/GoogleService-Info.plist with the new file. '
          'Open it and confirm it contains CLIENT_ID and REVERSED_CLIENT_ID.\n'
          '5. Xcode → Runner target → Info → URL Types → add a URL scheme '
          'whose value is exactly the REVERSED_CLIENT_ID from that plist.\n'
          '6. Clean build: flutter clean, then flutter pub get, then run again.\n\n'
          'If you still see this only when the password is wrong, search '
          'Firebase docs for “email enumeration protection”.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showFirebaseAuthExceptionSnackBar(
  BuildContext context,
  FirebaseAuthException e, {
  required bool isSignUp,
}) {
  debugPrint(
    'FirebaseAuthException code=${e.code} message=${e.message} '
    'email=${e.email} credential=${e.credential}',
  );

  if (!context.mounted) return;

  if (e.code == 'internal-error') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Firebase could not complete sign-in (iOS config is often the cause).',
        ),
        action: SnackBarAction(
          label: 'How to fix',
          onPressed: () => showFirebaseIosAuthSetupDialog(context),
        ),
      ),
    );
    return;
  }

  final message = _messageForAuthException(e, isSignUp: isSignUp);
  debugPrint(
    '[CareSignal][Auth] mapped message for code=${e.code} isSignUp=$isSignUp '
    '-> $message',
  );
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _messageForAuthException(
  FirebaseAuthException e, {
  required bool isSignUp,
}) {
  if (isSignUp) {
    return switch (e.code) {
      'email-already-in-use' => 'An account already exists for that email.',
      'invalid-email' => 'That email address looks invalid.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'operation-not-allowed' => 'Email sign-up is not enabled for this app.',
      _ => e.message ?? 'Sign up failed (${e.code}).',
    };
  }

  return switch (e.code) {
    'wrong-password' => 'Password is incorrect.',
    'user-not-found' ||
    'invalid-credential' ||
    'invalid-login-credentials' => 'Email or password is incorrect.',
    'invalid-email' => 'That email address looks invalid.',
    'user-disabled' => 'This account has been disabled.',
    'network-request-failed' =>
      'Network error. Check your connection and try again.',
    'too-many-requests' =>
      'Too many attempts. Wait a minute and try again.',
    'operation-not-allowed' =>
      'Email sign-in is not enabled for this app in Firebase.',
    _ => e.message ?? 'Sign in failed (${e.code}).',
  };
}
