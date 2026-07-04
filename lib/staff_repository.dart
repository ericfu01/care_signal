import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'account_type.dart';
import 'family_models.dart';
import 'volunteer_background_check.dart';

class StaffRepository {
  StaffRepository._();

  static final StaffRepository instance = StaffRepository._();

  Stream<List<UserProfile>> watchPendingBackgroundChecks() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('accountType', isEqualTo: AccountType.volunteer)
        .where('backgroundCheckStatus', isEqualTo: VolunteerBackgroundCheckStatus.pending)
        .snapshots()
        .map((snap) => snap.docs.map(UserProfile.fromDoc).toList());
  }

  Future<void> reviewBackgroundCheck({
    required String volunteerUid,
    required bool approve,
    String? note,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(volunteerUid).set({
      'backgroundCheckStatus':
          approve ? VolunteerBackgroundCheckStatus.approved : VolunteerBackgroundCheckStatus.rejected,
      if (note != null && note.trim().isNotEmpty)
        'backgroundCheckNote': note.trim(),
      'backgroundCheckReviewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitFeedback({
    required String message,
    String? email,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final text = message.trim();
    if (text.isEmpty) {
      throw StateError('Enter a message before sending feedback.');
    }
    await FirebaseFirestore.instance.collection('feedback').add({
      'uid': uid,
      'email': email?.trim(),
      'message': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchFeedback() {
    return FirebaseFirestore.instance
        .collection('feedback')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchStaffInvites() {
    return FirebaseFirestore.instance
        .collection('staff_invites')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs);
  }
}
