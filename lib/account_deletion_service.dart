import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService._();

  static final AccountDeletionService instance = AccountDeletionService._();

  Future<void> deleteCurrentAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to delete your account.');
    }

    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
      'deleteUserAccount',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 120),
      ),
    );
    await callable.call<Map<String, dynamic>>({});
    // Auth user is already deleted by the Cloud Function; clear local session.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
