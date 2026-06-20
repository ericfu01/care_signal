import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'family_chat_repository.dart';
import 'family_models.dart';
import 'family_repository.dart';
import 'notification_repository.dart';
import 'notification_service.dart';

/// Debug-only helpers to test notifications on a single device.
class NotificationDebug {
  NotificationDebug._();

  static Future<String?> runSelfTest(BuildContext context) async {
    if (!kDebugMode) return 'Only available in debug builds';

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'Sign in first';

    final me = await FamilyRepository.instance.getUserProfile(uid);
    final familyId = me?.familyId?.trim() ?? '';
    if (familyId.isEmpty) {
      return 'Join or create a family first (Profile → family setup).';
    }

    UserProfile? other;
    final membersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('familyId', isEqualTo: familyId)
        .get();
    for (final doc in membersSnap.docs) {
      if (doc.id != uid) {
        other = UserProfile.fromDoc(doc);
        break;
      }
    }

    final otherUid = other?.uid ?? '';
    final otherName = other?.displayName ?? 'Test member';
    final chatId = otherUid.isNotEmpty
        ? FamilyChatRepository.dmChatId(uid, otherUid)
        : 'debug_chat';

    final id = 'debug_${DateTime.now().millisecondsSinceEpoch}';
    const title = 'Message from Test';
    const body = 'Debug notification — tap to try opening chat.';

    try {
      await NotificationRepository.instance.createDebugFamilyMessageNotification(
        id: id,
        title: title,
        body: body,
        familyId: familyId,
        chatId: chatId,
        otherUid: otherUid.isNotEmpty ? otherUid : 'debug',
        otherDisplayName: otherName,
      );
    } catch (e) {
      return 'Inbox write failed (deploy firestore rules?): $e';
    }

    await NotificationService.instance.showDebugFamilyMessageBanner(
      title: title,
      body: body,
      familyId: familyId,
      chatId: chatId,
      otherUid: otherUid.isNotEmpty ? otherUid : 'debug',
      otherDisplayName: otherName,
    );

    if (other == null && context.mounted) {
      return 'Inbox + banner sent. Add another family member to test tap → chat.';
    }
    return null;
  }
}
