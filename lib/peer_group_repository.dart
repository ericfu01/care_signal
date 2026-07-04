import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'family_models.dart';
import 'peer_group_models.dart';

class PeerGroupRepository {
  PeerGroupRepository._();

  static final PeerGroupRepository instance = PeerGroupRepository._();

  CollectionReference<Map<String, dynamic>> get _groups =>
      FirebaseFirestore.instance.collection('peer_groups');

  DocumentReference<Map<String, dynamic>> _userRequestRef(
    String uid,
    String groupId,
  ) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('peer_group_requests')
          .doc(groupId);

  Future<String?> _uid() async => FirebaseAuth.instance.currentUser?.uid;

  Future<String?> _email() async =>
      FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();

  Future<void> deleteCatalogDemoGroups() async {
    final snap = await _groups.where('isCatalogDemo', isEqualTo: true).get();
    if (snap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<UserProfile?> findVolunteerByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('resolveVolunteerByEmail');
      final result = await callable.call<Map<String, dynamic>>({
        'email': normalized,
      });
      final data = result.data;
      if (data['found'] != true) return null;
      final uid = data['uid'] as String?;
      if (uid == null || uid.isEmpty) return null;
      return UserProfile(
        uid: uid,
        displayName: (data['displayName'] as String?)?.trim() ?? 'Volunteer',
      );
    } catch (_) {
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _coHostInviteRef(
    String inviteeUid,
    String groupId,
  ) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(inviteeUid)
          .collection('peer_group_cohost_invites')
          .doc(groupId);

  DocumentReference<Map<String, dynamic>> _groupCoHostInviteRef(
    String groupId,
    String inviteeUid,
  ) =>
      _groups.doc(groupId).collection('cohost_invitations').doc(inviteeUid);

  Stream<List<PeerGroupRecord>> watchPublicGroups() {
    return _groups.where('isCatalogDemo', isEqualTo: false).snapshots().map(
          (snap) => snap.docs
              .map(PeerGroupRecord.fromDoc)
              .where((group) => group.hasHost)
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title)),
        );
  }

  Stream<List<PeerGroupRecord>> watchManagedGroups(String uid) {
    return _groups.where('isCatalogDemo', isEqualTo: false).snapshots().map(
          (snap) => snap.docs
              .map(PeerGroupRecord.fromDoc)
              .where((group) => group.isManagedBy(uid))
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title)),
        );
  }

  Stream<PeerGroupRecord?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return PeerGroupRecord.fromDoc(snap);
    });
  }

  Future<PeerGroupRecord?> fetchGroup(String groupId) async {
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return null;
    return PeerGroupRecord.fromDoc(snap);
  }

  Stream<int> watchParticipantCount(String groupId) {
    return watchParticipants(groupId).map((participants) => participants.length);
  }

  Stream<List<PeerGroupRecord>> watchPendingCoHostInvites(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('peer_group_cohost_invites')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snap) async {
      final groups = <PeerGroupRecord>[];
      for (final doc in snap.docs) {
        final groupId = doc.data()['groupId'] as String?;
        if (groupId == null || groupId.isEmpty) continue;
        final groupSnap = await _groups.doc(groupId).get();
        if (!groupSnap.exists) continue;
        groups.add(PeerGroupRecord.fromDoc(groupSnap));
      }
      groups.sort((a, b) => a.title.compareTo(b.title));
      return groups;
    });
  }

  /// Volunteer-created peer support group.
  Future<String> createGroup({
    required String hostUid,
    required String title,
    required String schedule,
    required String mode,
    required String membersLabel,
  }) async {
    final ref = _groups.doc();
    await ref.set({
      'title': title.trim(),
      'schedule': schedule.trim(),
      'mode': mode.trim(),
      'membersLabel': membersLabel.trim(),
      'hostUid': hostUid,
      'cohostUids': <String>[],
      'isCatalogDemo': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<List<PeerGroupJoinRequest>> watchJoinRequests(String groupId) {
    return _groups
        .doc(groupId)
        .collection('join_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(PeerGroupJoinRequest.fromDoc).toList(),
        );
  }

  Stream<List<PeerGroupMember>> watchParticipants(String groupId) {
    return _groups
        .doc(groupId)
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .asyncMap((memberSnap) async {
      final participants = memberSnap.docs.map(PeerGroupMember.fromDoc).toList();
      final knownUids = participants.map((m) => m.memberUid).toSet();

      final acceptedSnap = await _groups
          .doc(groupId)
          .collection('join_requests')
          .where('status', isEqualTo: 'accepted')
          .get();
      for (final doc in acceptedSnap.docs) {
        final request = PeerGroupJoinRequest.fromDoc(doc);
        if (!knownUids.contains(request.requesterUid)) {
          participants.add(PeerGroupMember.fromJoinRequest(request));
        }
      }

      participants.sort(
        (a, b) => (a.memberName).toLowerCase().compareTo(b.memberName.toLowerCase()),
      );
      return participants;
    });
  }

  Future<void> _addMember({
    required String groupId,
    required String memberUid,
    required String memberName,
    required String source,
  }) async {
    await _groups.doc(groupId).collection('members').doc(memberUid).set({
      'memberUid': memberUid,
      'memberName': memberName.trim().isEmpty ? 'Member' : memberName.trim(),
      'source': source,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitJoinRequest({
    required String groupId,
    required String groupTitle,
    required String requesterUid,
    required String requesterName,
  }) async {
    final requestRef = _groups.doc(groupId).collection('join_requests').doc(requesterUid);
    await requestRef.set({
      'requesterUid': requesterUid,
      'requesterName': requesterName,
      'groupId': groupId,
      'groupTitle': groupTitle,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _userRequestRef(requesterUid, groupId).set({
      'groupId': groupId,
      'groupTitle': groupTitle,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToJoinRequest({
    required String groupId,
    required String requesterUid,
    required bool accept,
  }) async {
    final status = accept ? 'accepted' : 'declined';
    final requestRef =
        _groups.doc(groupId).collection('join_requests').doc(requesterUid);
    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data() ?? {};
    final requesterName =
        (requestData['requesterName'] as String?)?.trim() ?? 'Member';
    final groupTitle = (requestData['groupTitle'] as String?)?.trim();

    await requestRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _userRequestRef(requesterUid, groupId).set({
      'groupId': groupId,
      if (groupTitle != null && groupTitle.isNotEmpty) 'groupTitle': groupTitle,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (accept) {
      await _addMember(
        groupId: groupId,
        memberUid: requesterUid,
        memberName: requesterName,
        source: 'join_request',
      );
    }
  }

  Future<void> sendInvitation({
    required String groupId,
    required String groupTitle,
    required String hostUid,
    required String inviteeEmail,
    String? inviteeUid,
  }) async {
    final email = inviteeEmail.trim().toLowerCase();
    if (email.isEmpty) {
      throw StateError('Enter an email address to invite.');
    }
    // Always key by email on the client; Cloud Functions resolve account UIDs.
    final invitationId = email;
    await _groups.doc(groupId).collection('invitations').doc(invitationId).set({
      'groupId': groupId,
      'groupTitle': groupTitle,
      'inviteeEmail': email,
      if (inviteeUid != null && inviteeUid.isNotEmpty) 'inviteeUid': inviteeUid,
      'hostUid': hostUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<PeerGroupInvitation>> loadInvitationsForGroups(
    Iterable<String> groupIds,
  ) async {
    final uid = await _uid();
    if (uid == null) return [];

    final email = await _email();
    final invites = <String, PeerGroupInvitation>{};

    for (final groupId in groupIds) {
      final ref = _groups.doc(groupId).collection('invitations');

      final uidDoc = await ref.doc(uid).get();
      if (uidDoc.exists &&
          (uidDoc.data()?['status'] as String? ?? '') == 'pending') {
        invites[groupId] = PeerGroupInvitation.fromDoc(uidDoc, groupId: groupId);
        continue;
      }

      if (email != null && email.isNotEmpty) {
        final emailDoc = await ref.doc(email).get();
        if (emailDoc.exists &&
            (emailDoc.data()?['status'] as String? ?? '') == 'pending') {
          invites[groupId] =
              PeerGroupInvitation.fromDoc(emailDoc, groupId: groupId);
        }
      }
    }

    return invites.values.toList();
  }

  Future<void> acceptInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    final uid = await _uid();
    if (uid == null) return;
    final email = await _email();
    final user = FirebaseAuth.instance.currentUser;
    var memberName = user?.displayName?.trim();
    if (memberName == null || memberName.isEmpty) {
      memberName = email?.split('@').first ?? 'Member';
    }

    await _groups.doc(groupId).collection('invitations').doc(invitationId).set({
      'status': 'accepted',
      'inviteeUid': uid,
      'inviteeEmail': ?email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('peer_group_requests')
        .doc(groupId)
        .set({
      'groupId': groupId,
      'status': 'accepted',
      'source': 'invitation',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addMember(
      groupId: groupId,
      memberUid: uid,
      memberName: memberName,
      source: 'invitation',
    );
  }

  Future<PeerGroupMemberStatus?> _statusFromJoinRequest(
    String groupId,
    String uid,
  ) async {
    final snap =
        await _groups.doc(groupId).collection('join_requests').doc(uid).get();
    if (!snap.exists) return null;
    final status = snap.data()?['status'] as String? ?? 'pending';
    return switch (status) {
      'accepted' => PeerGroupMemberStatus.accepted,
      'declined' => PeerGroupMemberStatus.declined,
      _ => PeerGroupMemberStatus.pending,
    };
  }

  Future<PeerGroupMemberStatus> memberStatusForGroup(String groupId) async {
    final uid = await _uid();
    if (uid == null) return PeerGroupMemberStatus.none;

    final invites = await loadInvitationsForGroups([groupId]);
    if (invites.any((i) => i.isPending)) {
      return PeerGroupMemberStatus.invited;
    }

    final userReq = await _userRequestRef(uid, groupId).get();
    if (!userReq.exists) return PeerGroupMemberStatus.none;
    final status = userReq.data()?['status'] as String? ?? 'pending';
    return switch (status) {
      'accepted' => PeerGroupMemberStatus.accepted,
      'declined' => PeerGroupMemberStatus.declined,
      'removed' => PeerGroupMemberStatus.none,
      _ => PeerGroupMemberStatus.pending,
    };
  }

  Future<Map<String, PeerGroupMemberStatus>> loadMemberStatuses(
    Iterable<String> groupIds,
  ) async {
    final result = <String, PeerGroupMemberStatus>{};
    final invites = await loadInvitationsForGroups(groupIds);
    final invitedIds =
        invites.where((i) => i.isPending).map((i) => i.groupId).toSet();

    final uid = await _uid();
    if (uid == null) {
      for (final id in groupIds) {
        result[id] = PeerGroupMemberStatus.none;
      }
      return result;
    }

    for (final groupId in groupIds) {
      if (invitedIds.contains(groupId)) {
        result[groupId] = PeerGroupMemberStatus.invited;
        continue;
      }
      final fromJoin = await _statusFromJoinRequest(groupId, uid);
      if (fromJoin != null) {
        result[groupId] = fromJoin;
        continue;
      }
      final snap = await _userRequestRef(uid, groupId).get();
      if (!snap.exists) {
        result[groupId] = PeerGroupMemberStatus.none;
        continue;
      }
      final status = snap.data()?['status'] as String? ?? 'pending';
      result[groupId] = switch (status) {
        'accepted' => PeerGroupMemberStatus.accepted,
        'declined' => PeerGroupMemberStatus.declined,
        'removed' => PeerGroupMemberStatus.none,
        _ => PeerGroupMemberStatus.pending,
      };
    }
    return result;
  }

  Stream<List<PeerGroupInvitation>> watchGroupInvitations(String groupId) {
    return _groups
        .doc(groupId)
        .collection('invitations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => PeerGroupInvitation.fromDoc(doc, groupId: groupId))
              .toList(),
        );
  }

  Stream<List<PeerGroupCoHostInvitation>> watchGroupCoHostInvitations(
    String groupId,
  ) {
    return _groups
        .doc(groupId)
        .collection('cohost_invitations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => PeerGroupCoHostInvitation.fromDoc(
                  doc,
                  groupId: groupId,
                ),
              )
              .toList(),
        );
  }

  Stream<List<PeerGroupCoHostInvitation>> watchPendingCoHostInvitesForUser(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('peer_group_cohost_invites')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => PeerGroupCoHostInvitation.fromDoc(
                  doc,
                  groupId: doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> cancelInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    await _groups.doc(groupId).collection('invitations').doc(invitationId).set({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendCoHostInvitation({
    required String groupId,
    required String groupTitle,
    required String hostUid,
    required String hostName,
    required String inviteeEmail,
  }) async {
    final email = inviteeEmail.trim().toLowerCase();
    if (email.isEmpty) {
      throw StateError('Enter a volunteer email to invite as co-host.');
    }

    final invitee = await findVolunteerByEmail(email);
    if (invitee == null) {
      throw StateError(
        'No approved volunteer account found for that email.',
      );
    }
    if (invitee.uid == hostUid) {
      throw StateError('You are already the host of this group.');
    }

    final groupSnap = await _groups.doc(groupId).get();
    if (!groupSnap.exists) {
      throw StateError('This group no longer exists.');
    }
    final group = PeerGroupRecord.fromDoc(groupSnap);
    if (group.hostUid != hostUid) {
      throw StateError('Only the primary host can invite co-hosts.');
    }
    if (group.cohostUids.contains(invitee.uid)) {
      throw StateError('${invitee.displayName} is already a co-host.');
    }

    final payload = {
      'groupId': groupId,
      'groupTitle': groupTitle,
      'inviteeUid': invitee.uid,
      'inviteeEmail': email,
      'inviteeName': invitee.displayName,
      'hostUid': hostUid,
      'hostName': hostName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = FirebaseFirestore.instance.batch();
    batch.set(_coHostInviteRef(invitee.uid, groupId), payload);
    batch.set(_groupCoHostInviteRef(groupId, invitee.uid), payload);
    await batch.commit();
  }

  Future<void> acceptCoHostInvitation({
    required String groupId,
  }) async {
    final uid = await _uid();
    if (uid == null) return;

    final inviteSnap = await _coHostInviteRef(uid, groupId).get();
    if (!inviteSnap.exists) {
      throw StateError('This co-host invitation is no longer available.');
    }
    final status = inviteSnap.data()?['status'] as String? ?? '';
    if (status != 'pending') {
      throw StateError('This co-host invitation has already been handled.');
    }

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_coHostInviteRef(uid, groupId), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_groupCoHostInviteRef(groupId, uid), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_groups.doc(groupId), {
      'cohostUids': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> declineCoHostInvitation({
    required String groupId,
  }) async {
    final uid = await _uid();
    if (uid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.set(_coHostInviteRef(uid, groupId), {
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_groupCoHostInviteRef(groupId, uid), {
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> removeCoHost({
    required String groupId,
    required String cohostUid,
  }) async {
    await _groups.doc(groupId).update({
      'cohostUids': FieldValue.arrayRemove([cohostUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _groupCoHostInviteRef(groupId, cohostUid).delete();
    await _coHostInviteRef(cohostUid, groupId).delete();
  }

  Future<void> removeParticipant({
    required String groupId,
    required String memberUid,
  }) async {
    await _groups.doc(groupId).collection('members').doc(memberUid).delete();
    await _userRequestRef(memberUid, groupId).set({
      'groupId': groupId,
      'status': 'removed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
