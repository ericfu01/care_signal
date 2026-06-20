import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_repository.dart';
import 'notification_service.dart';

/// Shared sign-out flow used by caregiver and volunteer experiences.
class AuthSession {
  AuthSession._();

  static Future<bool> confirmSignOut(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'You will need to sign in again to use Care Signal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    return go == true;
  }

  static Future<void> signOutAndNavigate(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FamilyRepository.instance.setVolunteerOnline(uid: uid, online: false);
      } catch (_) {}
    }

    await NotificationService.instance.onSignOut();
    await FirebaseAuth.instance.signOut();
  }

  static Future<void> confirmAndSignOut(BuildContext context) async {
    if (!context.mounted) return;
    if (await confirmSignOut(context) && context.mounted) {
      await signOutAndNavigate(context);
    }
  }
}
