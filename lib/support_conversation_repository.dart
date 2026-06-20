import 'package:cloud_firestore/cloud_firestore.dart';

import 'support_conversation_models.dart';

class SupportConversationRepository {
  SupportConversationRepository._();

  static final SupportConversationRepository instance =
      SupportConversationRepository._();

  CollectionReference<Map<String, dynamic>> _conversationsRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('support_conversations');
  }

  CollectionReference<Map<String, dynamic>> messagesRef(
    String uid,
    String conversationId,
  ) {
    return _conversationsRef(uid)
        .doc(conversationId)
        .collection('messages');
  }

  Stream<List<SupportConversation>> watchConversations(String uid) {
    return _conversationsRef(uid)
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs.map(SupportConversation.fromDoc).toList(),
        );
  }

  Future<String> createConversation(String uid) async {
    final ref = await _conversationsRef(uid).add({
      'title': 'New chat',
      'titleGenerated': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> touchConversation(String uid, String conversationId) async {
    await _conversationsRef(uid).doc(conversationId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setConversationTitle(
    String uid,
    String conversationId,
    String title, {
    bool titleGenerated = true,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _conversationsRef(uid).doc(conversationId).update({
      'title': trimmed.length > 80 ? '${trimmed.substring(0, 77)}…' : trimmed,
      'titleGenerated': titleGenerated,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
