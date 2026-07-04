import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'community_event_repository.dart';
import 'family_check_in_loader.dart';
import 'family_insights_copy.dart';
import 'family_models.dart';
import 'family_repository.dart';
import 'address_place.dart';
import 'support_recommendations.dart';
import 'request_duration.dart';
import 'request_priority.dart';
import 'peer_group_repository.dart';
import 'volunteer_matching.dart';
import 'volunteer_repository.dart';

/// Firestore-backed support sign-ups, volunteer requests, and preferences.
class SupportRepository {
  SupportRepository._();

  static final SupportRepository instance = SupportRepository._();

  CollectionReference<Map<String, dynamic>> _userSub(
    String uid,
    String name,
  ) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection(name);

  Future<String?> _uid() async => FirebaseAuth.instance.currentUser?.uid;

  Future<Map<String, dynamic>> _familyRequestContext() async {
    final uid = await _uid();
    if (uid == null) return {};
    final profile = await FamilyRepository.instance.getUserProfile(uid);
    final zip = await getUserZipCode();
    final home = await getUserHomeAddress();
    return {
      'familyUid': uid,
      if (profile != null) 'familyDisplayName': profile.displayName,
      if (profile?.email != null && profile!.email!.trim().isNotEmpty)
        'familyEmail': profile.email!.trim(),
      if (zip != null && zip.isNotEmpty) 'zipCode': zip,
      if (home != null && !home.isEmpty) ...{
        'homeAddress': home.formattedAddress,
        if (home.latitude != null) 'homeLat': home.latitude,
        if (home.longitude != null) 'homeLng': home.longitude,
      },
    };
  }

  Future<Map<String, dynamic>> _laneAssignmentFields({
    required String catalogId,
    required DateTime when,
    required int durationMinutes,
    required bool urgent,
    String? preferredVolunteerUid,
  }) async {
    if (urgent) {
      return {
        'volunteerId': catalogId,
        'priority': RequestPriority.urgent,
        'volunteerName': VolunteerMatching.instance.laneFallbackName(catalogId),
      };
    }

    final conflict = await VolunteerMatching.instance.scheduleConflictMessage(
      catalogId: catalogId,
      start: when,
      durationMinutes: durationMinutes,
      volunteerUid: preferredVolunteerUid,
    );
    if (conflict != null) {
      throw StateError(conflict);
    }

    if (preferredVolunteerUid != null && preferredVolunteerUid.isNotEmpty) {
      final profile = await FamilyRepository.instance.getUserProfile(
        preferredVolunteerUid,
      );
      if (profile != null) {
        return {
          'volunteerId': catalogId,
          'priority': RequestPriority.normal,
          'volunteerUid': preferredVolunteerUid,
          'volunteerName': profile.displayName,
        };
      }
    }

    final match = await VolunteerMatching.instance.findAvailableVolunteer(
      catalogId,
      windowStart: when,
      durationMinutes: durationMinutes,
    );
    return {
      'volunteerId': catalogId,
      'priority': RequestPriority.normal,
      if (match != null) ...{
        'volunteerUid': match.volunteerUid,
        'volunteerName': match.displayName,
      } else
        'volunteerName': VolunteerMatching.instance.laneFallbackName(catalogId),
    };
  }

  Future<void> respondToCounterProposal({
    required String requestId,
    required bool accept,
  }) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Sign in to respond.');
    await VolunteerRepository.instance.familyRespondToCounter(
      familyUserId: uid,
      requestId: requestId,
      accept: accept,
    );
  }

  Future<void> cancelVolunteerRequest(String requestId) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Sign in to cancel.');
    await VolunteerRepository.instance.familyCancelRequest(
      familyUserId: uid,
      requestId: requestId,
    );
  }

  Future<Map<String, dynamic>?> getVolunteerRequest(String requestId) async {
    final uid = await _uid();
    if (uid == null || requestId.isEmpty) return null;
    try {
      final snap = await _userSub(uid, 'volunteer_requests').doc(requestId).get();
      if (!snap.exists) return null;
      return {...snap.data() ?? {}, 'requestId': snap.id};
    } catch (_) {
      return null;
    }
  }

  Future<bool> getShareWithPartners() async {
    final uid = await _uid();
    if (uid == null) return true;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final value = snap.data()?['shareWithPartners'];
      return value is bool ? value : true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setShareWithPartners(bool value) async {
    final uid = await _uid();
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'shareWithPartners': value},
      SetOptions(merge: true),
    );
    if (value) {
      await syncLatestPartnerWellnessSnapshot();
    } else {
      await clearPartnerWellnessSnapshot();
    }
  }

  Future<void> clearPartnerWellnessSnapshot() async {
    final uid = await _uid();
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'partnerWellnessSnapshot': FieldValue.delete()},
      SetOptions(merge: true),
    );
    await FirebaseFirestore.instance.collection('partner_shares').doc(uid).delete();
  }

  Future<void> syncPartnerWellnessSnapshot({
    required int score,
    required String dayKey,
    required List<String> stressSources,
  }) async {
    if (!await getShareWithPartners()) return;
    final uid = await _uid();
    if (uid == null) return;

    final topStress = stressSources.take(3).toList();
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'partnerWellnessSnapshot': {
          'score': score,
          'dayKey': dayKey,
          'topStressSources': topStress,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
    await FirebaseFirestore.instance.collection('partner_shares').doc(uid).set({
      'score': score,
      'dayKey': dayKey,
      'topStressSources': topStress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> syncLatestPartnerWellnessSnapshot() async {
    if (!await getShareWithPartners()) return;
    final uid = await _uid();
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_check_ins')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;
      final data = snap.docs.first.data();
      final score = (data['score'] as num?)?.round();
      if (score == null) return;

      var dayKeyValue = data['dayKey'] as String?;
      if (dayKeyValue == null || dayKeyValue.isEmpty) {
        final created = data['createdAt'];
        if (created is Timestamp) {
          final local = created.toDate().toLocal();
          dayKeyValue = FamilyCheckInLoader.dayKey(
            DateTime(local.year, local.month, local.day),
          );
        } else {
          dayKeyValue = FamilyCheckInLoader.dayKey(DateTime.now());
        }
      }
      final sources = data['stressSources'];
      final stressList = sources is List
          ? sources.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : <String>[];
      await syncPartnerWellnessSnapshot(
        score: score,
        dayKey: dayKeyValue,
        stressSources: stressList,
      );
    } catch (_) {}
  }

  Future<bool> getShareTrendsEnabled() async {
    final uid = await _uid();
    if (uid == null) return false;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final value = snap.data()?['shareTrendsEnabled'];
      return value is bool ? value : false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setShareTrendsEnabled(bool value) async {
    final uid = await _uid();
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'shareTrendsEnabled': value},
      SetOptions(merge: true),
    );
  }

  Future<Map<String, bool>> getShareTrendsEnabledByUids(
    Iterable<String> uids,
  ) async {
    final unique = uids.where((uid) => uid.isNotEmpty).toSet();
    if (unique.isEmpty) return {};

    final prefs = <String, bool>{};
    await Future.wait(
      unique.map((uid) async {
        try {
          final snap =
              await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final value = snap.data()?['shareTrendsEnabled'];
          prefs[uid] = value is bool ? value : false;
        } catch (_) {
          prefs[uid] = false;
        }
      }),
    );
    return prefs;
  }

  /// Whether [viewerUid] may see wellness trends for [memberUid].
  static bool canViewMemberTrends({
    required String memberUid,
    required String? viewerUid,
    required Map<String, bool> shareTrendsByUid,
  }) {
    if (viewerUid != null && memberUid == viewerUid) return true;
    return shareTrendsByUid[memberUid] ?? false;
  }

  Future<bool> getRiskAlertsEnabled() async {
    final uid = await _uid();
    if (uid == null) return true;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final value = snap.data()?['riskAlertsEnabled'];
      return value is bool ? value : true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setRiskAlertsEnabled(bool value) async {
    final uid = await _uid();
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'riskAlertsEnabled': value},
      SetOptions(merge: true),
    );
  }

  Future<String?> getUserZipCode() async {
    final uid = await _uid();
    if (uid == null) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final zip = snap.data()?['zipCode'] as String?;
      return zip?.trim().isNotEmpty == true ? zip!.trim() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserZipCode(String zipCode) async {
    final uid = await _uid();
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'zipCode': zipCode.trim()},
      SetOptions(merge: true),
    );
  }

  Future<AddressPlace?> getUserHomeAddress() async {
    final uid = await _uid();
    if (uid == null) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data()?['homeAddress'];
      if (data is! Map<String, dynamic>) return null;
      final place = AddressPlace.fromMap(data);
      return place.isEmpty ? null : place;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserHomeAddress(AddressPlace place) async {
    final uid = await _uid();
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'homeAddress': place.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<AddressPlace?> getLastRidePickup() async {
    final uid = await _uid();
    if (uid == null) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data()?['lastRidePickup'];
      if (data is! Map<String, dynamic>) return null;
      final place = AddressPlace.fromMap(data);
      return place.isEmpty ? null : place;
    } catch (_) {
      return null;
    }
  }

  Future<AddressPlace?> getLastRideDestination() async {
    final uid = await _uid();
    if (uid == null) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data()?['lastRideDestination'];
      if (data is! Map<String, dynamic>) return null;
      final place = AddressPlace.fromMap(data);
      return place.isEmpty ? null : place;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastRideAddresses({
    AddressPlace? pickup,
    AddressPlace? destination,
  }) async {
    final uid = await _uid();
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (pickup != null && !pickup.isEmpty) {
      updates['lastRidePickup'] = pickup.toMap();
    }
    if (destination != null && !destination.isEmpty) {
      updates['lastRideDestination'] = destination.toMap();
    }
    if (updates.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      updates,
      SetOptions(merge: true),
    );
  }

  Future<FamilyInsightsCopy?> loadInsightsCopy() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final profile = await FamilyRepository.instance.getUserProfile(user.uid);
    if (profile == null) {
      return FamilyInsightsCopy(
        currentUserName: 'You',
        memberNames: const ['You'],
        memberScores: const {'You': null},
      );
    }
    if (profile.familyId == null || profile.familyId!.isEmpty) {
      return FamilyInsightsCopy(
        currentUserName: profile.displayName,
        memberNames: [profile.displayName],
        memberScores: {profile.displayName: null},
      );
    }

    List<UserProfile> members;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('familyId', isEqualTo: profile.familyId!)
          .get();
      members = snap.docs.map(UserProfile.fromDoc).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    } catch (_) {
      members = [profile];
    }
    final memberNames = members.map((m) => m.displayName).toList();
    final memberScores =
        await FamilyCheckInLoader.latestScoresByMemberName(members);
    final stressSourceCounts = await _stressSourceCountsForUser(user.uid);

    return FamilyInsightsCopy(
      currentUserName: profile.displayName,
      memberNames: memberNames,
      memberScores: memberScores,
      stressSourceCounts: stressSourceCounts,
    );
  }

  Future<PersonalizedSupportPlan> loadPersonalizedSupportPlan() async {
    final insights = await loadInsightsCopy();
    if (insights == null) return PersonalizedSupportPlan.empty();
    final shareWithPartners = await getShareWithPartners();
    return SupportRecommendations.fromInsights(
      insights,
      shareWithPartners: shareWithPartners,
    );
  }

  Future<Map<String, int>> _stressSourceCountsForUser(String uid) async {
    final counts = <String, int>{};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_check_ins')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();
      for (final doc in snap.docs) {
        final sources = doc.data()['stressSources'];
        if (sources is! List) continue;
        for (final source in sources) {
          final key = source.toString();
          if (key.isEmpty) continue;
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    } catch (_) {}
    return counts;
  }

  Future<bool> hasPeerGroupRequest(String groupId) async {
    final uid = await _uid();
    if (uid == null) return false;
    try {
      final snap = await _userSub(uid, 'peer_group_requests').doc(groupId).get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> submitPeerGroupRequest({
    required String groupId,
    required String groupTitle,
  }) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Sign in to join a group.');
    if (!await getShareWithPartners()) {
      throw StateError(
        'Turn on Share with Partners in Support to join partner peer groups.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    final requesterName = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? 'Member');
    await PeerGroupRepository.instance.submitJoinRequest(
      groupId: groupId,
      groupTitle: groupTitle,
      requesterUid: uid,
      requesterName: requesterName,
    );
  }

  Future<bool> hasEventSignup(String eventId) async {
    return CommunityEventRepository.instance.hasSignup(eventId);
  }

  Future<int> eventSignupCount(String eventId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('community_events')
          .doc(eventId)
          .get();
      return (snap.data()?['signupCount'] as num?)?.round() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> submitEventSignup({
    required String eventId,
    required String eventTitle,
    required String name,
    required String email,
    String? phone,
    required int familyCount,
  }) async {
    await CommunityEventRepository.instance.submitSignup(
      eventId: eventId,
      eventTitle: eventTitle,
      name: name,
      email: email,
      phone: phone,
      familyCount: familyCount,
    );
  }

  Future<void> submitVolunteerSchedule({
    required String volunteerId,
    required String volunteerName,
    required DateTime scheduledAt,
    required int durationMinutes,
    required bool urgent,
    String? volunteerUid,
    String? instructions,
  }) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Sign in to schedule.');
    final assignment = await _laneAssignmentFields(
      catalogId: volunteerId,
      when: scheduledAt,
      durationMinutes: durationMinutes,
      urgent: urgent,
      preferredVolunteerUid: volunteerUid,
    );
    final contextFields = await _familyRequestContext();
    await _userSub(uid, 'volunteer_requests').add({
      ...contextFields,
      ...RequestDuration.fields(durationMinutes),
      ...assignment,
      'serviceType': 'respite',
      'label': 'Scheduled respite visit',
      'needsNow': false,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      if (instructions != null && instructions.trim().isNotEmpty)
        'instructions': instructions.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitServiceRequest({
    required String serviceType,
    required String label,
    required int durationMinutes,
    required bool needsNow,
    required bool urgent,
    DateTime? scheduledAt,
    String? instructions,
  }) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Sign in to request support.');
    if (!needsNow && scheduledAt == null) {
      throw ArgumentError('Choose a date and time for your request.');
    }

    final catalogId = VolunteerMatching.catalogIdForServiceType(serviceType);
    final when = needsNow ? DateTime.now() : scheduledAt!;
    if (!needsNow && !when.isAfter(DateTime.now())) {
      throw ArgumentError('Choose a date and time in the future.');
    }

    final assignment = catalogId == null
        ? <String, dynamic>{}
        : await _laneAssignmentFields(
            catalogId: catalogId,
            when: when,
            durationMinutes: durationMinutes,
            urgent: urgent,
          );
    final contextFields = await _familyRequestContext();
    await _userSub(uid, 'volunteer_requests').add({
      ...contextFields,
      ...RequestDuration.fields(durationMinutes),
      ...assignment,
      'serviceType': serviceType,
      'label': label,
      'needsNow': needsNow,
      'scheduledAt': Timestamp.fromDate(when),
      if (instructions != null && instructions.trim().isNotEmpty)
        'instructions': instructions.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitTransportationRequest({
    required bool needsNow,
    DateTime? scheduledAt,
    AddressPlace? pickupPlace,
    AddressPlace? destinationPlace,
    required String zipCode,
    required bool volunteerCoverageAvailable,
    required int durationMinutes,
    required bool urgent,
    bool followUpOnly = false,
  }) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Sign in to request a ride.');
    if (!needsNow && scheduledAt == null && !followUpOnly) {
      throw ArgumentError('Choose a date and time for a scheduled ride.');
    }

    final assignVolunteer = volunteerCoverageAvailable && !followUpOnly;
    final when = needsNow
        ? DateTime.now()
        : scheduledAt ?? DateTime.now().add(const Duration(days: 1));

    const transportLaneId = VolunteerMatching.transportCatalogId;
    final contextFields = await _familyRequestContext();
    final assignment = assignVolunteer
        ? await _laneAssignmentFields(
            catalogId: transportLaneId,
            when: when,
            durationMinutes: durationMinutes,
            urgent: urgent,
          )
        : <String, dynamic>{};

    await _userSub(uid, 'volunteer_requests').add({
      ...contextFields,
      ...RequestDuration.fields(durationMinutes),
      ...assignment,
      'serviceType': 'transport',
      'label': followUpOnly
          ? 'Transportation · Follow-up'
          : needsNow
              ? 'Transportation · ASAP'
              : 'Transportation',
      'needsNow': needsNow,
      'scheduledAt': Timestamp.fromDate(when),
      'zipCode': zipCode.trim(),
      'volunteerCoverageAvailable': volunteerCoverageAvailable,
      'followUpOnly': followUpOnly,
      if (pickupPlace != null && !pickupPlace.isEmpty) ...{
        'pickup': pickupPlace.formattedAddress,
        if (pickupPlace.latitude != null) 'pickupLat': pickupPlace.latitude,
        if (pickupPlace.longitude != null) 'pickupLng': pickupPlace.longitude,
      },
      if (destinationPlace != null && !destinationPlace.isEmpty) ...{
        'destination': destinationPlace.formattedAddress,
        if (destinationPlace.latitude != null)
          'destinationLat': destinationPlace.latitude,
        if (destinationPlace.longitude != null)
          'destinationLng': destinationPlace.longitude,
      },
      'status': followUpOnly ? 'follow_up' : 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await saveUserZipCode(zipCode);
  }

  Stream<List<Map<String, dynamic>>> watchVolunteerMessages({
    required String volunteerId,
  }) {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<Map<String, dynamic>>[]);
      return _userSub(user.uid, 'volunteer_messages')
          .doc(volunteerId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => d.data()).toList(),
          );
    });
  }

  Future<void> sendVolunteerMessage({
    required String volunteerId,
    required String volunteerName,
    required String text,
    required bool isUser,
  }) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Sign in to message.');
    final profile = await FamilyRepository.instance.getUserProfile(uid);
    final thread = _userSub(uid, 'volunteer_messages').doc(volunteerId);
    await thread.set({
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      if (profile != null) 'familyDisplayName': profile.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await thread.collection('messages').add({
      'text': text.trim(),
      'isUser': isUser,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> seedVolunteerGreeting({
    required String volunteerId,
    required String volunteerName,
    required String greeting,
  }) async {
    final uid = await _uid();
    if (uid == null) return;
    final messages = _userSub(uid, 'volunteer_messages')
        .doc(volunteerId)
        .collection('messages');
    final existing = await messages.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    await sendVolunteerMessage(
      volunteerId: volunteerId,
      volunteerName: volunteerName,
      text: greeting,
      isUser: false,
    );
  }

  Stream<List<Map<String, dynamic>>> watchVolunteerRequests() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<Map<String, dynamic>>[]);
      return _userSub(user.uid, 'volunteer_requests')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => {...d.data(), 'requestId': d.id})
                .toList(),
          );
    });
  }

  Future<VolunteerImpactSummary> loadVolunteerImpact() async {
    final uid = await _uid();
    if (uid == null) {
      return const VolunteerImpactSummary(hours: 0, meals: 0, rides: 0);
    }
    try {
      final snap = await _userSub(uid, 'volunteer_requests').get();
      var respitePeerMinutes = 0;
      var meals = 0;
      var rides = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['status'] != 'completed') continue;

        final type = data['serviceType'] as String? ?? '';
        final minutes = (data['durationMinutes'] as num?)?.toInt();
        final duration = minutes != null && minutes > 0
            ? minutes
            : RequestDuration.defaultForService(type);

        switch (type) {
          case 'respite':
          case 'peer':
            respitePeerMinutes += duration;
          case 'meal':
            meals += 1;
          case 'transport':
            if (data['followUpOnly'] == true) break;
            rides += 1;
        }
      }
      final hours = (respitePeerMinutes / 60).round();
      return VolunteerImpactSummary(hours: hours, meals: meals, rides: rides);
    } catch (_) {
      return const VolunteerImpactSummary(hours: 0, meals: 0, rides: 0);
    }
  }
}

class VolunteerImpactSummary {
  const VolunteerImpactSummary({
    required this.hours,
    required this.meals,
    required this.rides,
  });

  final int hours;
  final int meals;
  final int rides;
}
