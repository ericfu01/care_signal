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

    final callable =
        FirebaseFunctions.instance.httpsCallable('deleteUserAccount');
    await callable.call<Map<String, dynamic>>({});
    await FirebaseAuth.instance.signOut();
  }
}
