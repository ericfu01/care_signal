import 'package:cloud_firestore/cloud_firestore.dart';

import 'family_chat_models.dart';
import 'family_models.dart';

/// Direct messages between two family members under `families/{id}/family_chats`.
class FamilyChatRepository {
  FamilyChatRepository._();

  static final FamilyChatRepository instance = FamilyChatRepository._();

  static String dmChatId(String uidA, String uidB) {
    final pair = [uidA, uidB]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  CollectionReference<Map<String, dynamic>> _chats(String familyId) {
    return FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('family_chats');
  }

  CollectionReference<Map<String, dynamic>> _messages(
    String familyId,
    String chatId,
  ) {
    return _chats(familyId).doc(chatId).collection('messages');
  }

  Stream<List<FamilyChatThread>> watchThreads({
    required String familyId,
    required String myUid,
  }) {
    // Sort in the app so the inbox works without waiting on a composite index.
    return _chats(familyId)
        .where('participantUids', arrayContains: myUid)
        .snapshots()
        .map((snap) {
          final threads = snap.docs.map(FamilyChatThread.fromDoc).toList();
          threads.sort((a, b) {
            final at = a.lastMessageAt;
            final bt = b.lastMessageAt;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
          return threads;
        });
  }

  Stream<List<FamilyChatMessage>> watchMessages({
    required String familyId,
    required String chatId,
  }) {
    return _messages(familyId, chatId)
        .orderBy('createdAt', descending: false)
        .limit(500)
        .snapshots()
        .map(
          (snap) => snap.docs.map(FamilyChatMessage.fromDoc).toList(),
        );
  }

  Future<String> openOrCreateThread({
    required String familyId,
    required UserProfile me,
    required UserProfile other,
  }) async {
    if (me.uid == other.uid) {
      throw ArgumentError('Cannot message yourself');
    }
    final chatId = dmChatId(me.uid, other.uid);
    final uids = [me.uid, other.uid]..sort();
    await _chats(familyId).doc(chatId).set(
      {
        'participantUids': uids,
        'participantNames': {
          me.uid: me.displayName,
          other.uid: other.displayName,
        },
        'lastMessageText': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return chatId;
  }

  Future<void> sendMessage({
    required String familyId,
    required String chatId,
    required String senderUid,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final messageRef = _messages(familyId, chatId).doc();
    batch.set(messageRef, {
      'senderUid': senderUid,
      'senderName': senderName,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _chats(familyId).doc(chatId),
      {
        'lastMessageText': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
