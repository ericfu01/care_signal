import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_notification.dart';

class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  Stream<List<AppNotification>> watchNotifications({int limit = 50}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _notifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map(AppNotification.fromDoc).toList(),
        );
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (list) => list.where((n) => !n.read).length,
    );
  }

  Future<void> markRead(String notificationId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _notifications(uid).doc(notificationId).update({'read': true});
  }

  /// Debug-only row in the notifications inbox (requires [debugOnly] in rules).
  Future<void> createDebugFamilyMessageNotification({
    required String id,
    required String title,
    required String body,
    required String familyId,
    required String chatId,
    required String otherUid,
    required String otherDisplayName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _notifications(uid).doc(id).set({
      'type': 'family_message',
      'title': title,
      'body': body,
      'familyId': familyId,
      'chatId': chatId,
      'otherUid': otherUid,
      'otherDisplayName': otherDisplayName,
      'read': false,
      'debugOnly': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await _notifications(uid).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
