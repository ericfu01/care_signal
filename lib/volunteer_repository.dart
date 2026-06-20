import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'request_duration.dart';
import 'request_priority.dart';
import 'volunteer_availability.dart';

/// A family support request assigned to a volunteer lane.
class VolunteerAssignment {
  const VolunteerAssignment({
    required this.familyUserId,
    required this.requestId,
    required this.data,
  });

  final String familyUserId;
  final String requestId;
  final Map<String, dynamic> data;

  String get serviceType => data['serviceType'] as String? ?? '';
  String get label => data['label'] as String? ?? 'Support request';
  String get status => data['status'] as String? ?? 'pending';
  bool get isUrgent => RequestPriority.isUrgent(data);
  bool get needsNow => data['needsNow'] == true;
  bool get followUpOnly => data['followUpOnly'] == true;
  String? get pickup => data['pickup'] as String?;
  String? get destination => data['destination'] as String?;
  String? get zipCode => data['zipCode'] as String?;
  String? get volunteerCatalogId => data['volunteerId'] as String?;
  String? get volunteerUid => data['volunteerUid'] as String?;
  String? get familyDisplayName => data['familyDisplayName'] as String?;
  String? get familyEmail => data['familyEmail'] as String?;
  String? get homeAddress => data['homeAddress'] as String?;
  String? get notes {
    final instructions = data['instructions'] as String?;
    if (instructions != null && instructions.trim().isNotEmpty) {
      return instructions.trim();
    }
    final value = data['notes'] as String?;
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  int get durationMinutes {
    final minutes = (data['durationMinutes'] as num?)?.toInt();
    if (minutes != null && minutes > 0) return minutes;
    return RequestDuration.defaultForService(serviceType);
  }

  String get durationLabel =>
      (data['durationLabel'] as String?)?.trim().isNotEmpty == true
          ? (data['durationLabel'] as String).trim()
          : RequestDuration.label(durationMinutes);

  Timestamp? get blockedStartAt {
    final value = data['blockedStartAt'];
    return value is Timestamp ? value : null;
  }

  Timestamp? get blockedEndAt {
    final value = data['blockedEndAt'];
    return value is Timestamp ? value : null;
  }

  String get blockedWindowLabel {
    final start = blockedStartAt?.toDate().toLocal();
    final end = blockedEndAt?.toDate().toLocal();
    if (start == null || end == null) {
      return durationLabel;
    }
    final startText =
        VolunteerAvailabilitySchedule.formatWindowStart(start);
    final endText = VolunteerAvailabilitySchedule.formatMinutes(
      end.hour * 60 + end.minute,
    );
    return '$durationLabel · $startText – $endText';
  }

  Timestamp? get scheduledAt {
    final value = data['scheduledAt'];
    return value is Timestamp ? value : null;
  }

  Timestamp? get createdAt {
    final value = data['createdAt'];
    return value is Timestamp ? value : null;
  }

  Timestamp? get counterScheduledAt {
    final value = data['counterScheduledAt'];
    return value is Timestamp ? value : null;
  }

  String? get counterVolunteerUid => data['counterVolunteerUid'] as String?;
  String? get counterVolunteerName => data['counterVolunteerName'] as String?;

  String counterWhenLabel() {
    final counter = counterScheduledAt;
    if (counter == null) return 'Alternate time proposed';
    final dt = counter.toDate().toLocal();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} · $hour:$minute $period';
  }

  String get serviceTypeLabel {
    switch (serviceType) {
      case 'respite':
        return 'Respite care';
      case 'meal':
        return 'Meal delivery';
      case 'transport':
        return followUpOnly ? 'Transportation follow-up' : 'Transportation';
      case 'peer':
        return 'Peer support';
      default:
        return label;
    }
  }

  String get familyName => familyDisplayName?.trim().isNotEmpty == true
      ? familyDisplayName!.trim()
      : 'Family member';

  String get locationSummary {
    final parts = <String>[];
    if (zipCode != null && zipCode!.trim().isNotEmpty) {
      parts.add('ZIP ${zipCode!.trim()}');
    }
    if (homeAddress != null && homeAddress!.trim().isNotEmpty) {
      parts.add(homeAddress!.trim());
    }
    return parts.join(' · ');
  }

  String get routeSummary {
    final parts = <String>[];
    if (pickup != null && pickup!.isNotEmpty) parts.add(pickup!);
    if (destination != null && destination!.isNotEmpty) {
      parts.add(destination!);
    }
    return parts.join(' → ');
  }

  String whenLabel() {
    if (status == 'counter_proposed') {
      final name = counterVolunteerName ?? 'Volunteer';
      return '$name suggested ${counterWhenLabel()} · $durationLabel';
    }
    if (needsNow) {
      return 'Needed as soon as possible · $durationLabel';
    }
    final scheduled = scheduledAt;
    if (scheduled == null) {
      return 'Time to be confirmed · $durationLabel';
    }
    final dt = scheduled.toDate().toLocal();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} · $hour:$minute $period · $durationLabel';
  }
}

class VolunteerMessageThread {
  const VolunteerMessageThread({
    required this.familyUserId,
    required this.volunteerCatalogId,
    required this.volunteerName,
    this.familyDisplayName,
    this.updatedAt,
  });

  final String familyUserId;
  final String volunteerCatalogId;
  final String volunteerName;
  final String? familyDisplayName;
  final DateTime? updatedAt;
}

class VolunteerStats {
  const VolunteerStats({
    required this.pending,
    required this.active,
    required this.completed,
  });

  final int pending;
  final int active;
  final int completed;

  factory VolunteerStats.fromAssignments(List<VolunteerAssignment> items) {
    var pending = 0;
    var active = 0;
    var completed = 0;
    for (final item in items) {
      switch (item.status) {
        case 'pending':
        case 'follow_up':
        case 'counter_proposed':
          pending++;
        case 'accepted':
          active++;
        case 'completed':
          completed++;
      }
    }
    return VolunteerStats(
      pending: pending,
      active: active,
      completed: completed,
    );
  }
}

class VolunteerRepository {
  VolunteerRepository._();

  static final VolunteerRepository instance = VolunteerRepository._();

  Future<VolunteerAssignment?> fetchAssignment({
    required String familyUserId,
    required String requestId,
  }) async {
    if (familyUserId.isEmpty || requestId.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(familyUserId)
          .collection('volunteer_requests')
          .doc(requestId)
          .get();
      if (!snap.exists) return null;
      return VolunteerAssignment(
        familyUserId: familyUserId,
        requestId: requestId,
        data: snap.data() ?? {},
      );
    } catch (_) {
      return null;
    }
  }

  Stream<List<VolunteerAssignment>> watchAssignments(String volunteerCatalogId) {
    if (volunteerCatalogId.isEmpty) {
      return Stream.value(const []);
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return FirebaseFirestore.instance
        .collectionGroup('volunteer_requests')
        .where('volunteerId', isEqualTo: volunteerCatalogId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => VolunteerAssignment(
                  familyUserId: doc.reference.parent.parent!.id,
                  requestId: doc.id,
                  data: doc.data(),
                ),
              )
              .where((assignment) => _visibleToVolunteer(assignment, myUid))
              .toList(),
        );
  }

  bool _visibleToVolunteer(VolunteerAssignment assignment, String? myUid) {
    if (myUid == null || myUid.isEmpty) return false;
    if (assignment.status == 'counter_proposed') {
      return assignment.counterVolunteerUid == myUid;
    }
    if (assignment.isUrgent) return true;
    final assigned = assignment.volunteerUid;
    if (assigned == null || assigned.isEmpty) return true;
    return assigned == myUid;
  }

  Stream<List<VolunteerMessageThread>> watchMessageThreads(
    String volunteerCatalogId,
  ) {
    if (volunteerCatalogId.isEmpty) {
      return Stream.value(const []);
    }

    return FirebaseFirestore.instance
        .collectionGroup('volunteer_messages')
        .where('volunteerId', isEqualTo: volunteerCatalogId)
        .orderBy('updatedAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return VolunteerMessageThread(
              familyUserId: doc.reference.parent.parent!.id,
              volunteerCatalogId: volunteerCatalogId,
              volunteerName: data['volunteerName'] as String? ?? 'Volunteer',
              familyDisplayName: data['familyDisplayName'] as String?,
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
            );
          }).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> watchFamilyMessages({
    required String familyUserId,
    required String volunteerCatalogId,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(familyUserId)
        .collection('volunteer_messages')
        .doc(volunteerCatalogId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> updateAssignmentStatus({
    required String familyUserId,
    required String requestId,
    required String status,
    String? volunteerUid,
    String? volunteerName,
  }) async {
    final requestRef = FirebaseFirestore.instance
        .collection('users')
        .doc(familyUserId)
        .collection('volunteer_requests')
        .doc(requestId);

    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (volunteerUid != null && volunteerUid.isNotEmpty) {
      updates['volunteerUid'] = volunteerUid;
    }
    if (volunteerName != null && volunteerName.trim().isNotEmpty) {
      updates['volunteerName'] = volunteerName.trim();
    }

    final creditedVolunteerUid =
        volunteerUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (status == 'accepted' &&
        creditedVolunteerUid != null &&
        creditedVolunteerUid.isNotEmpty) {
      final volunteerRef =
          FirebaseFirestore.instance.collection('users').doc(creditedVolunteerUid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        final volunteerSnap = await tx.get(volunteerRef);
        if (!requestSnap.exists) return;
        final requestData = requestSnap.data() ?? {};
        if (requestData['status'] == 'accepted') return;

        final now = DateTime.now();
        final block = VolunteerAvailability.blockForRequest(
          requestData: requestData,
          requestId: requestId,
          familyUserId: familyUserId,
          now: now,
        );

        final volunteerData = volunteerSnap.data() ?? {};
        final schedule = VolunteerAvailabilitySchedule.fromFirestore(
          volunteerData['volunteerAvailabilitySchedule'] ??
              volunteerData['volunteerAvailability'],
        );
        final existingBlocks = VolunteerAvailabilityBlocks.fromFirestore(
          volunteerData['volunteerAvailabilityBlocks'],
        );
        final nextBlocks =
            existingBlocks.withoutExpired(now).adding(block).toFirestore();
        final mergedBlocks =
            VolunteerAvailabilityBlocks.fromFirestore(nextBlocks);
        final online = VolunteerAvailability.isAvailable(
          schedule: schedule,
          blocks: mergedBlocks,
          moment: now,
        );

        tx.set(
          requestRef,
          {
            ...updates,
            'blockedStartAt': Timestamp.fromDate(block.startAt),
            'blockedEndAt': Timestamp.fromDate(block.endAt),
            'acceptedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.set(
          volunteerRef,
          {
            'volunteerAvailabilityBlocks': nextBlocks,
            'volunteerOnline': online,
          },
          SetOptions(merge: true),
        );
      });
      return;
    }

    if (status == 'completed' &&
        creditedVolunteerUid != null &&
        creditedVolunteerUid.isNotEmpty) {
      final volunteerRef =
          FirebaseFirestore.instance.collection('users').doc(creditedVolunteerUid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        final volunteerSnap = await tx.get(volunteerRef);
        if (!requestSnap.exists) return;
        if (requestSnap.data()?['status'] == 'completed') return;

        final data = volunteerSnap.data() ?? {};
        final statsRaw = data['volunteerStats'];
        final stats = statsRaw is Map
            ? Map<String, dynamic>.from(statsRaw)
            : <String, dynamic>{};

        final helpedIds = <String>{
          ...((stats['helpedFamilyIds'] as List?) ?? const [])
              .whereType<String>(),
        };
        helpedIds.add(familyUserId);

        final completedVisits =
            ((stats['completedVisits'] as num?)?.toInt() ?? 0) + 1;

        final now = DateTime.now();
        final schedule = VolunteerAvailabilitySchedule.fromFirestore(
          data['volunteerAvailabilitySchedule'] ?? data['volunteerAvailability'],
        );
        final existingBlocks = VolunteerAvailabilityBlocks.fromFirestore(
          data['volunteerAvailabilityBlocks'],
        );
        final nextBlocks = existingBlocks
            .withoutExpired(now)
            .removingRequest(requestId)
            .toFirestore();
        final mergedBlocks =
            VolunteerAvailabilityBlocks.fromFirestore(nextBlocks);
        final online = VolunteerAvailability.isAvailable(
          schedule: schedule,
          blocks: mergedBlocks,
          moment: now,
        );

        tx.set(requestRef, updates, SetOptions(merge: true));

        tx.set(
          volunteerRef,
          {
            'volunteerStats': {
              'completedVisits': completedVisits,
              'familiesHelped': helpedIds.length,
              'helpedFamilyIds': helpedIds.toList(),
            },
            'volunteerAvailabilityBlocks': nextBlocks,
            'volunteerOnline': online,
          },
          SetOptions(merge: true),
        );
      });
      return;
    }

    await requestRef.set(updates, SetOptions(merge: true));
  }

  Future<void> proposeCounterTime({
    required String familyUserId,
    required String requestId,
    required DateTime counterScheduledAt,
    required String volunteerUid,
    required String volunteerName,
  }) async {
    if (!counterScheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError('Choose a date and time in the future.');
    }

    final requestRef = FirebaseFirestore.instance
        .collection('users')
        .doc(familyUserId)
        .collection('volunteer_requests')
        .doc(requestId);

    await requestRef.set(
      {
        'status': 'counter_proposed',
        'counterScheduledAt': Timestamp.fromDate(counterScheduledAt),
        'counterVolunteerUid': volunteerUid,
        'counterVolunteerName': volunteerName.trim(),
        'counterProposedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> familyRespondToCounter({
    required String familyUserId,
    required String requestId,
    required bool accept,
  }) async {
    final requestRef = FirebaseFirestore.instance
        .collection('users')
        .doc(familyUserId)
        .collection('volunteer_requests')
        .doc(requestId);

    if (!accept) {
      await requestRef.set(
        {
          'status': 'pending',
          'counterScheduledAt': FieldValue.delete(),
          'counterVolunteerUid': FieldValue.delete(),
          'counterVolunteerName': FieldValue.delete(),
          'counterProposedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return;
    }

    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw StateError('Request not found.');
    }
    final requestData = requestSnap.data() ?? {};
    if (requestData['status'] != 'counter_proposed') {
      throw StateError('Counter proposal is no longer available.');
    }

    final counterAt = (requestData['counterScheduledAt'] as Timestamp?)?.toDate();
    final volunteerUid = requestData['counterVolunteerUid'] as String?;
    final volunteerName = requestData['counterVolunteerName'] as String?;
    if (counterAt == null || volunteerUid == null || volunteerUid.isEmpty) {
      throw StateError('Counter proposal is no longer available.');
    }

    final now = DateTime.now();
    final mergedData = {
      ...requestData,
      'scheduledAt': Timestamp.fromDate(counterAt),
      'needsNow': false,
      'volunteerUid': volunteerUid,
      if (volunteerName != null && volunteerName.trim().isNotEmpty)
        'volunteerName': volunteerName.trim(),
    };
    final block = VolunteerAvailability.blockForRequest(
      requestData: mergedData,
      requestId: requestId,
      familyUserId: familyUserId,
      now: now,
    );

    await requestRef.set(
      {
        'status': 'accepted',
        'scheduledAt': Timestamp.fromDate(counterAt),
        'needsNow': false,
        'volunteerUid': volunteerUid,
        if (volunteerName != null && volunteerName.trim().isNotEmpty)
          'volunteerName': volunteerName.trim(),
        'blockedStartAt': Timestamp.fromDate(block.startAt),
        'blockedEndAt': Timestamp.fromDate(block.endAt),
        'acceptedAt': FieldValue.serverTimestamp(),
        'counterScheduledAt': FieldValue.delete(),
        'counterVolunteerUid': FieldValue.delete(),
        'counterVolunteerName': FieldValue.delete(),
        'counterProposedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> familyCancelRequest({
    required String familyUserId,
    required String requestId,
  }) async {
    final requestRef = FirebaseFirestore.instance
        .collection('users')
        .doc(familyUserId)
        .collection('volunteer_requests')
        .doc(requestId);

    final snap = await requestRef.get();
    if (!snap.exists) {
      throw StateError('Request not found.');
    }

    final data = snap.data() ?? {};
    final status = data['status'] as String? ?? 'pending';
    if (status == 'cancelled' || status == 'completed') {
      throw StateError('This request can no longer be cancelled.');
    }

    final updates = <String, dynamic>{
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'counter_proposed') {
      updates['counterScheduledAt'] = FieldValue.delete();
      updates['counterVolunteerUid'] = FieldValue.delete();
      updates['counterVolunteerName'] = FieldValue.delete();
      updates['counterProposedAt'] = FieldValue.delete();
    }

    await requestRef.set(updates, SetOptions(merge: true));
  }

  /// Applies calendar blocks from accepted assignments to the signed-in volunteer.
  Future<void> syncAvailabilityBlocksFromAcceptedRequests(String uid) async {
    if (uid.isEmpty) return;

    final volunteerRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final volunteerSnap = await volunteerRef.get();
    if (!volunteerSnap.exists) return;

    final volunteerData = volunteerSnap.data() ?? {};
    final catalogId = volunteerData['volunteerCatalogId'] as String?;
    if (catalogId == null || catalogId.isEmpty) return;

    final requestsSnap = await FirebaseFirestore.instance
        .collectionGroup('volunteer_requests')
        .where('volunteerId', isEqualTo: catalogId)
        .where('status', isEqualTo: 'accepted')
        .get();

    final now = DateTime.now();
    final existing = VolunteerAvailabilityBlocks.fromFirestore(
      volunteerData['volunteerAvailabilityBlocks'],
    ).withoutExpired(now);

    var desired = VolunteerAvailabilityBlocks(blocks: const []);
    for (final doc in requestsSnap.docs) {
      final data = doc.data();
      final assignedUid = data['volunteerUid'] as String?;
      if (assignedUid != null &&
          assignedUid.isNotEmpty &&
          assignedUid != uid) {
        continue;
      }
      final block = VolunteerAvailability.blockForRequest(
        requestData: data,
        requestId: doc.id,
        familyUserId: doc.reference.parent.parent!.id,
        now: now,
      );
      desired = desired.adding(block);
    }
    desired = desired.withoutExpired(now);

    final existingIds = existing.blocks.map((b) => b.requestId!).toList()
      ..sort();
    final desiredIds = desired.blocks.map((b) => b.requestId!).toList()..sort();
    if (existingIds.length == desiredIds.length &&
        _listEquals(existingIds, desiredIds)) {
      return;
    }

    final schedule = VolunteerAvailabilitySchedule.fromFirestore(
      volunteerData['volunteerAvailabilitySchedule'] ??
          volunteerData['volunteerAvailability'],
    );
    final online = VolunteerAvailability.isAvailable(
      schedule: schedule,
      blocks: desired,
      moment: now,
    );

    await volunteerRef.set(
      {
        'volunteerAvailabilityBlocks': desired.toFirestore(),
        'volunteerOnline': online,
      },
      SetOptions(merge: true),
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> sendVolunteerReply({
    required String familyUserId,
    required String volunteerCatalogId,
    required String volunteerName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final thread = FirebaseFirestore.instance
        .collection('users')
        .doc(familyUserId)
        .collection('volunteer_messages')
        .doc(volunteerCatalogId);

    await thread.set(
      {
        'volunteerId': volunteerCatalogId,
        'volunteerName': volunteerName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await thread.collection('messages').add({
      'text': trimmed,
      'isUser': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> familyDisplayName(String familyUserId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(familyUserId)
          .get();
      final name = snap.data()?['displayName'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return null;
  }
}
