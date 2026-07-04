import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'family_models.dart';
import 'account_type.dart';
import 'volunteer_availability.dart';

/// Firestore-backed families and invite codes.
class FamilyRepository {
  FamilyRepository._();

  static final FamilyRepository instance = FamilyRepository._();

  static const _inviteLinkScheme = 'caresignal';
  static const _inviteLinkHost = 'join';

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  CollectionReference<Map<String, dynamic>> get _families =>
      FirebaseFirestore.instance.collection('families');

  CollectionReference<Map<String, dynamic>> get _invites =>
      FirebaseFirestore.instance.collection('family_invites');

  static String inviteLinkForCode(String inviteCode) {
    return '$_inviteLinkScheme://$_inviteLinkHost/${inviteCode.trim().toUpperCase()}';
  }

  /// Accepts a raw code or a pasted invite link.
  static String parseInviteCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      if (uri.scheme == _inviteLinkScheme &&
          uri.host.toLowerCase() == _inviteLinkHost) {
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.last.toUpperCase();
        }
        final path = uri.path.replaceFirst('/', '');
        if (path.isNotEmpty) return path.toUpperCase();
      }
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          segments[segments.length - 2].toLowerCase() == 'join') {
        return segments.last.toUpperCase();
      }
    }

    return trimmed.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    final profile = UserProfile.fromDoc(snap);
    await _migrateLegacyPeerGroupHostIfNeeded(uid, profile);
    return profile;
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final profile = UserProfile.fromDoc(snap);
      unawaited(_migrateLegacyPeerGroupHostIfNeeded(uid, profile));
      return profile;
    });
  }

  Future<void> _migrateLegacyPeerGroupHostIfNeeded(
    String uid,
    UserProfile profile,
  ) async {
    if (!AccountType.isLegacyPeerGroupHost(profile.accountType)) return;
    await _users.doc(uid).set(
      {'accountType': AccountType.volunteer},
      SetOptions(merge: true),
    );
  }

  Stream<List<UserProfile>> watchFamilyMembers(String familyId) {
    return _users
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map(
          (snap) => snap.docs.map(UserProfile.fromDoc).toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName)),
        );
  }

  Future<void> upsertUserProfile({
    required String uid,
    required String displayName,
    required String email,
    String accountType = AccountType.caregiver,
  }) async {
    await _users.doc(uid).set(
      UserProfile(
        uid: uid,
        displayName: displayName,
        email: email,
        accountType: accountType,
      ).toCreateMap(
        displayName: displayName,
        email: email,
        accountType: accountType,
      ),
      SetOptions(merge: true),
    );
  }

  Future<void> setVolunteerProfile({
    required String uid,
    required String volunteerCatalogId,
  }) async {
    await _users.doc(uid).set(
      {
        'accountType': AccountType.volunteer,
        'volunteerCatalogId': volunteerCatalogId,
        'volunteerOnline': false,
        'volunteerAvailabilitySchedule': const [],
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveVolunteerAvailabilitySchedule({
    required String uid,
    required VolunteerAvailabilitySchedule schedule,
  }) async {
    await _users.doc(uid).set(
      {
        'volunteerAvailabilitySchedule': schedule.toFirestore(),
      },
      SetOptions(merge: true),
    );
    await syncVolunteerOnlineFromSchedule(uid);
  }

  Future<bool> syncVolunteerOnlineFromSchedule(String uid) async {
    final profile = await getUserProfile(uid);
    if (profile == null || !profile.isVolunteer) return false;
    final online = profile.isVolunteerAvailableNow();
    if (profile.volunteerOnline == online) return online;
    await _users.doc(uid).set(
      {'volunteerOnline': online},
      SetOptions(merge: true),
    );
    return online;
  }

  Future<void> setVolunteerOnline({
    required String uid,
    required bool online,
  }) async {
    await _users.doc(uid).set(
      {'volunteerOnline': online},
      SetOptions(merge: true),
    );
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Display name cannot be empty');
    }
    await _users.doc(uid).set(
      {'displayName': name},
      SetOptions(merge: true),
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid == uid) {
      await user.updateDisplayName(name);
      await user.reload();
    }
  }

  Future<FamilyRecord> createFamily({
    required String uid,
    String? familyName,
  }) async {
    final profile = await getUserProfile(uid);
    if (profile?.hasFamily == true) {
      throw StateError('You are already in a family');
    }

    final familyRef = _families.doc();
    final inviteCode = await _uniqueInviteCode();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(familyRef, {
        'inviteCode': inviteCode,
        'name': familyName?.trim().isNotEmpty == true
            ? familyName!.trim()
            : null,
        'createdByUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(_invites.doc(inviteCode), {
        'familyId': familyRef.id,
        'createdByUid': uid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        _users.doc(uid),
        {
          'familyId': familyRef.id,
          'familyRole': 'admin',
        },
        SetOptions(merge: true),
      );
    });

    final familySnap = await familyRef.get();
    return FamilyRecord.fromDoc(familySnap);
  }

  Future<FamilyRecord> joinFamilyWithInvite({
    required String uid,
    required String inviteInput,
  }) async {
    final code = parseInviteCode(inviteInput);
    if (code.isEmpty) {
      throw ArgumentError('Enter an invite code or paste an invite link');
    }

    final profile = await getUserProfile(uid);
    if (profile?.hasFamily == true) {
      throw StateError('Leave your current family before joining another');
    }

    final inviteSnap = await _invites.doc(code).get();
    if (!inviteSnap.exists) {
      throw StateError('Invite not found. Check the code and try again.');
    }
    final inviteData = inviteSnap.data() ?? {};
    if (inviteData['active'] == false) {
      throw StateError('This invite is no longer active');
    }
    final familyId = inviteData['familyId'] as String?;
    if (familyId == null || familyId.isEmpty) {
      throw StateError('Invalid invite');
    }

    await _users.doc(uid).set(
      {
        'familyId': familyId,
        'familyRole': 'member',
      },
      SetOptions(merge: true),
    );

    final familySnap = await _families.doc(familyId).get();
    if (!familySnap.exists) {
      throw StateError('Family no longer exists');
    }
    return FamilyRecord.fromDoc(familySnap);
  }

  Future<FamilyRecord?> getFamily(String familyId) async {
    final snap = await _families.doc(familyId).get();
    if (!snap.exists) return null;
    return FamilyRecord.fromDoc(snap);
  }

  Future<String> ensureInviteCodeForFamily(String familyId) async {
    final family = await getFamily(familyId);
    if (family == null) throw StateError('Family not found');
    if (family.inviteCode.isNotEmpty) return family.inviteCode;

    final code = await _uniqueInviteCode();
    await _families.doc(familyId).set(
      {'inviteCode': code},
      SetOptions(merge: true),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _invites.doc(code).set({
      'familyId': familyId,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      if (uid != null) 'createdByUid': uid,
    });
    return code;
  }

  Future<String> _uniqueInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = List.generate(
        8,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
      final existing = await _invites.doc(code).get();
      if (!existing.exists) return code;
    }
    throw StateError('Could not generate invite code');
  }
}
