import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `feedback/{id}` status values.
class FeedbackStatus {
  FeedbackStatus._();

  static const open = 'open';
  static const resolved = 'resolved';

  static String normalize(String? value) {
    if (value == resolved) return resolved;
    return open;
  }

  static bool isResolved(String? value) => normalize(value) == resolved;
}

/// Firestore `feedback/{id}`.
class FeedbackRecord {
  const FeedbackRecord({
    required this.id,
    required this.message,
    this.uid,
    this.email,
    this.photoUrls = const [],
    this.createdAt,
    this.status = FeedbackStatus.open,
    this.resolvedAt,
  });

  final String id;
  final String message;
  final String? uid;
  final String? email;
  final List<String> photoUrls;
  final DateTime? createdAt;
  final String status;
  final DateTime? resolvedAt;

  bool get hasPhotos => photoUrls.isNotEmpty;
  bool get isResolved => FeedbackStatus.isResolved(status);

  factory FeedbackRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final photos = (data['photoUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return FeedbackRecord(
      id: doc.id,
      message: (data['message'] as String?)?.trim() ?? '',
      uid: data['uid'] as String?,
      email: (data['email'] as String?)?.trim(),
      photoUrls: photos,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: FeedbackStatus.normalize(data['status'] as String?),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}
