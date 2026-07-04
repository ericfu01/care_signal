import 'package:cloud_firestore/cloud_firestore.dart';

/// In-app notification stored at `users/{uid}/notifications/{id}`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.familyId,
    this.chatId,
    this.otherUid,
    this.otherDisplayName,
    this.familyUserId,
    this.requestId,
    this.groupId,
    this.requesterUid,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
  final String? familyId;
  final String? chatId;
  final String? otherUid;
  final String? otherDisplayName;
  final String? familyUserId;
  final String? requestId;
  final String? groupId;
  final String? requesterUid;

  bool get isFamilyMessage => type == 'family_message';
  bool get isVolunteerRequestCancelled =>
      type == 'volunteer_request_cancelled';
  bool get isVolunteerRequestNew => type == 'volunteer_request_new';
  bool get isFamilyVolunteerRequestUpdate =>
      type == 'family_request_accepted' ||
      type == 'family_request_counter' ||
      type == 'family_request_completed' ||
      type == 'family_request_declined';
  bool get isFamilyRiskAlert => type == 'family_risk_alert';
  bool get isPeerGroupJoinRequest => type == 'peer_group_join_request';
  bool get isPeerGroupCoHostInvite => type == 'peer_group_cohost_invite';
  bool get isPeerGroupFamilyInvite => type == 'peer_group_family_invite';

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final created = data['createdAt'];
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? 'unknown',
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: created is Timestamp ? created.toDate() : null,
      familyId: data['familyId'] as String?,
      chatId: data['chatId'] as String?,
      otherUid: data['otherUid'] as String?,
      otherDisplayName: data['otherDisplayName'] as String?,
      familyUserId: data['familyUserId'] as String?,
      requestId: data['requestId'] as String?,
      groupId: data['groupId'] as String?,
      requesterUid: data['requesterUid'] as String?,
    );
  }
}
