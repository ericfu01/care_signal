import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'account_type.dart';
import 'family_models.dart';
import 'feedback_models.dart';
import 'feedback_photo_service.dart';
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
    final trimmedNote = note?.trim() ?? '';
    if (!approve && trimmedNote.isEmpty) {
      throw StateError('Add a short note so the volunteer knows what to fix.');
    }
    await FirebaseFirestore.instance.collection('users').doc(volunteerUid).set({
      'backgroundCheckStatus':
          approve ? VolunteerBackgroundCheckStatus.approved : VolunteerBackgroundCheckStatus.rejected,
      if (approve)
        'backgroundCheckNote': FieldValue.delete()
      else
        'backgroundCheckNote': trimmedNote,
      'backgroundCheckReviewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitFeedback({
    required String message,
    String? email,
    List<Uint8List> photoBytes = const [],
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to send feedback.');
    }
    final text = message.trim();
    if (text.isEmpty) {
      throw StateError('Enter a message before sending feedback.');
    }
    if (photoBytes.length > FeedbackPhotoService.maxPhotos) {
      throw StateError(
        'Attach up to ${FeedbackPhotoService.maxPhotos} photos.',
      );
    }

    final docRef = FirebaseFirestore.instance.collection('feedback').doc();
    await docRef.set({
      'uid': uid,
      'email': email?.trim(),
      'message': text,
      'photoUrls': <String>[],
      'photoCount': 0,
      'status': FeedbackStatus.open,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final urls = <String>[];
    for (var i = 0; i < photoBytes.length; i++) {
      final url = await FeedbackPhotoService.instance.uploadFeedbackPhoto(
        uid: uid,
        feedbackId: docRef.id,
        index: i,
        bytes: photoBytes[i],
      );
      urls.add(url);
    }

    if (urls.isNotEmpty) {
      await docRef.set({
        'photoUrls': urls,
        'photoCount': urls.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Stream<List<FeedbackRecord>> watchFeedback() {
    return FirebaseFirestore.instance
        .collection('feedback')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(FeedbackRecord.fromDoc).toList());
  }

  Future<void> setFeedbackStatus({
    required String feedbackId,
    required bool resolved,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('feedback').doc(feedbackId).set({
      'status': resolved ? FeedbackStatus.resolved : FeedbackStatus.open,
      if (resolved) ...{
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': uid,
      } else ...{
        'resolvedAt': FieldValue.delete(),
        'resolvedBy': FieldValue.delete(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
