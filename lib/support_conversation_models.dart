import 'package:cloud_firestore/cloud_firestore.dart';

/// Metadata for one support chat thread (`users/{uid}/support_conversations/{id}`).
class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.titleGenerated = false,
  });

  final String id;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool titleGenerated;

  factory SupportConversation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SupportConversation(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'New chat',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      titleGenerated: data['titleGenerated'] as bool? ?? false,
    );
  }
}
