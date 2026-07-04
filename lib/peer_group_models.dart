import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `peer_groups/{groupId}`.
class PeerGroupRecord {
  const PeerGroupRecord({
    required this.id,
    required this.title,
    required this.schedule,
    required this.mode,
    required this.membersLabel,
    required this.hostUid,
    this.cohostUids = const [],
    this.isCatalogDemo = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String schedule;
  final String mode;
  final String membersLabel;
  final String hostUid;
  final List<String> cohostUids;
  final bool isCatalogDemo;
  final DateTime? createdAt;

  bool get hasHost => hostUid.isNotEmpty;

  bool isManagedBy(String uid) => hostUid == uid || cohostUids.contains(uid);

  factory PeerGroupRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PeerGroupRecord(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? doc.id,
      schedule: (data['schedule'] as String?)?.trim() ?? '',
      mode: (data['mode'] as String?)?.trim() ?? '',
      membersLabel: (data['membersLabel'] as String?)?.trim() ?? '',
      hostUid: (data['hostUid'] as String?)?.trim() ?? '',
      cohostUids: (data['cohostUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      isCatalogDemo: data['isCatalogDemo'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap({
    required String hostUid,
  }) =>
      {
        'title': title,
        'schedule': schedule,
        'mode': mode,
        'membersLabel': membersLabel,
        'hostUid': hostUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class PeerGroupJoinRequest {
  const PeerGroupJoinRequest({
    required this.requesterUid,
    required this.requesterName,
    required this.status,
    this.createdAt,
    this.groupTitle,
  });

  final String requesterUid;
  final String requesterName;
  final String status;
  final DateTime? createdAt;
  final String? groupTitle;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  factory PeerGroupJoinRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PeerGroupJoinRequest(
      requesterUid: doc.id,
      requesterName: (data['requesterName'] as String?)?.trim() ?? 'Member',
      status: (data['status'] as String?) ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      groupTitle: data['groupTitle'] as String?,
    );
  }
}

/// Confirmed participant in `peer_groups/{groupId}/members/{memberUid}`.
class PeerGroupMember {
  const PeerGroupMember({
    required this.memberUid,
    required this.memberName,
    this.source,
    this.joinedAt,
  });

  final String memberUid;
  final String memberName;
  final String? source;
  final DateTime? joinedAt;

  String get participantSubtitle {
    if (source == 'invitation') {
      return 'Joined via invitation';
    }
    final joinedLabel = _formatJoinDate(joinedAt);
    if (joinedLabel == null) {
      return 'Joined via request';
    }
    return 'Joined via request · $joinedLabel';
  }

  static String? _formatJoinDate(DateTime? date) {
    if (date == null) return null;
    final local = date.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  factory PeerGroupMember.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PeerGroupMember(
      memberUid: doc.id,
      memberName: (data['memberName'] as String?)?.trim() ?? 'Member',
      source: data['source'] as String?,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory PeerGroupMember.fromJoinRequest(PeerGroupJoinRequest request) {
    return PeerGroupMember(
      memberUid: request.requesterUid,
      memberName: request.requesterName,
      source: 'join_request',
      joinedAt: request.createdAt,
    );
  }
}

class PeerGroupInvitation {
  const PeerGroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupTitle,
    required this.inviteeEmail,
    required this.status,
    this.inviteeUid,
    this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupTitle;
  final String inviteeEmail;
  final String? inviteeUid;
  final String status;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCancelled => status == 'cancelled';

  factory PeerGroupInvitation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String groupId,
  }) {
    final data = doc.data() ?? {};
    return PeerGroupInvitation(
      id: doc.id,
      groupId: groupId,
      groupTitle: (data['groupTitle'] as String?)?.trim() ?? groupId,
      inviteeEmail: (data['inviteeEmail'] as String?)?.trim().toLowerCase() ?? '',
      inviteeUid: data['inviteeUid'] as String?,
      status: (data['status'] as String?) ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Co-host invite stored on the group and invitee user doc.
class PeerGroupCoHostInvitation {
  const PeerGroupCoHostInvitation({
    required this.groupId,
    required this.groupTitle,
    required this.inviteeUid,
    required this.inviteeEmail,
    required this.inviteeName,
    required this.hostUid,
    required this.hostName,
    required this.status,
    this.createdAt,
  });

  final String groupId;
  final String groupTitle;
  final String inviteeUid;
  final String inviteeEmail;
  final String inviteeName;
  final String hostUid;
  final String hostName;
  final String status;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  factory PeerGroupCoHostInvitation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String groupId,
  }) {
    final data = doc.data() ?? {};
    return PeerGroupCoHostInvitation(
      groupId: groupId,
      groupTitle: (data['groupTitle'] as String?)?.trim() ?? groupId,
      inviteeUid: (data['inviteeUid'] as String?) ?? doc.id,
      inviteeEmail: (data['inviteeEmail'] as String?)?.trim().toLowerCase() ?? '',
      inviteeName: (data['inviteeName'] as String?)?.trim() ?? 'Volunteer',
      hostUid: (data['hostUid'] as String?) ?? '',
      hostName: (data['hostName'] as String?)?.trim() ?? 'Host',
      status: (data['status'] as String?) ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Member-side status for a catalog group.
enum PeerGroupMemberStatus {
  none,
  invited,
  pending,
  accepted,
  declined,
}
