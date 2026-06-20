import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'family_presence.dart';
import 'account_type.dart';
import 'volunteer_availability.dart';
import 'volunteer_profile_stats.dart';

/// `users/{uid}` profile fields used for family features.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.familyId,
    this.familyRole,
    this.accountType,
    this.volunteerCatalogId,
    this.volunteerOnline,
    this.weeklyAvailability = VolunteerAvailabilitySchedule.empty,
    this.availabilityBlocks = const VolunteerAvailabilityBlocks(),
    this.volunteerStats = const VolunteerProfileStats(),
    this.lastActiveAt,
    this.profilePhotoUrl,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? familyId;
  final String? familyRole;
  final String? accountType;
  final String? volunteerCatalogId;
  final bool? volunteerOnline;
  final VolunteerAvailabilitySchedule weeklyAvailability;
  final VolunteerAvailabilityBlocks availabilityBlocks;
  final VolunteerProfileStats volunteerStats;
  final DateTime? lastActiveAt;
  final String? profilePhotoUrl;

  /// Safe read for profiles loaded before weekly hours existed or after hot reload.
  VolunteerAvailabilitySchedule volunteerSchedule() {
    try {
      final schedule = weeklyAvailability;
      return schedule;
    } catch (_) {
      return VolunteerAvailabilitySchedule.empty;
    }
  }

  bool get hasFamily => familyId != null && familyId!.isNotEmpty;
  bool get isAdmin => familyRole == 'admin';
  bool get isVolunteer => AccountType.isVolunteer(accountType);
  bool get isCaregiver => AccountType.isCaregiver(accountType);
  bool get volunteerProfileComplete =>
      !isVolunteer || (volunteerCatalogId != null && volunteerCatalogId!.isNotEmpty);

  bool isVolunteerAvailableNow([DateTime? at]) {
    final moment = at ?? DateTime.now();
    return VolunteerAvailability.isAvailable(
      schedule: volunteerSchedule(),
      blocks: availabilityBlocks.withoutExpired(moment),
      moment: moment,
    );
  }

  bool isVolunteerAvailableForWindow({
    required DateTime start,
    required int durationMinutes,
  }) =>
      VolunteerAvailability.isAvailableForWindow(
        schedule: volunteerSchedule(),
        blocks: availabilityBlocks.withoutExpired(start),
        start: start,
        durationMinutes: durationMinutes,
      );

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'Member',
      email: data['email'] as String?,
      familyId: data['familyId'] as String?,
      familyRole: data['familyRole'] as String?,
      accountType: data['accountType'] as String?,
      volunteerCatalogId: data['volunteerCatalogId'] as String?,
      volunteerOnline: data['volunteerOnline'] as bool?,
      weeklyAvailability: VolunteerAvailabilitySchedule.fromFirestore(
        data['volunteerAvailabilitySchedule'] ?? data['volunteerAvailability'],
      ),
      availabilityBlocks: VolunteerAvailabilityBlocks.fromFirestore(
        data['volunteerAvailabilityBlocks'],
      ),
      volunteerStats: VolunteerProfileStats.fromFirestore(data['volunteerStats']),
      lastActiveAt: FamilyPresence.timestampToDate(data['lastActiveAt']),
      profilePhotoUrl: (data['profilePhotoUrl'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toCreateMap({
    required String displayName,
    required String email,
    String? accountType,
  }) {
    return {
      'displayName': displayName.trim(),
      'email': email.trim(),
      'accountType': accountType ?? AccountType.caregiver,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// `families/{familyId}` document.
class FamilyRecord {
  const FamilyRecord({
    required this.id,
    required this.inviteCode,
    this.name,
    required this.createdByUid,
  });

  final String id;
  final String inviteCode;
  final String? name;
  final String createdByUid;

  factory FamilyRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FamilyRecord(
      id: doc.id,
      inviteCode: (data['inviteCode'] as String?) ?? '',
      name: data['name'] as String?,
      createdByUid: (data['createdByUid'] as String?) ?? '',
    );
  }
}

/// UI model for home/profile family rows.
class FamilyMemberView {
  const FamilyMemberView({
    required this.uid,
    required this.name,
    required this.initials,
    required this.wellness,
    required this.avatarColor,
    required this.wellnessColor,
    required this.isCurrentUser,
    this.isAdmin = false,
    required this.presenceLabel,
    required this.isOnline,
    this.photoUrl,
  });

  final String uid;
  final String name;
  final String initials;
  final String wellness;
  final Color avatarColor;
  final Color wellnessColor;
  final bool isCurrentUser;
  final bool isAdmin;
  final String presenceLabel;
  final bool isOnline;
  final String? photoUrl;
}

String initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return w.length >= 2
        ? w.substring(0, 2).toUpperCase()
        : w[0].toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String wellnessLabelFromScore(int? score) {
  if (score == null) return 'No check-in yet';
  if (score >= 85) return 'Excellent';
  if (score >= 70) return 'Good';
  if (score >= 55) return 'Stable';
  if (score >= 40) return 'Moderate';
  return 'Needs support';
}

Color wellnessColorFromScore(int? score) {
  if (score == null) return const Color(0xFF9E9E9E);
  if (score >= 85) return const Color(0xFF1B8A5A);
  if (score >= 70) return const Color(0xFF2E7D32);
  if (score >= 55) return const Color(0xFF6D4C41);
  if (score >= 40) return const Color(0xFFEF6C00);
  return const Color(0xFFC62828);
}

const _avatarPalette = [
  Color(0xFF4DB6AC),
  Color(0xFF64B5F6),
  Color(0xFFBA68C8),
  Color(0xFFFFB74D),
  Color(0xFFE57373),
  Color(0xFF81C784),
  Color(0xFF9575CD),
];

Color avatarColorForUid(String uid) {
  var hash = 0;
  for (final c in uid.codeUnits) {
    hash = (hash + c) % 1000;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}

FamilyMemberView familyMemberViewFromProfile({
  required UserProfile profile,
  required String currentUid,
  int? latestScore,
  required bool currentUserAppActive,
}) {
  final score = profile.uid == currentUid ? latestScore : null;
  final isSelf = profile.uid == currentUid;
  final online = isSelf && currentUserAppActive
      ? true
      : FamilyPresence.isOnline(profile.lastActiveAt);
  return FamilyMemberView(
    uid: profile.uid,
    name: profile.displayName,
    initials: initialsFromName(profile.displayName),
    wellness: wellnessLabelFromScore(score),
    avatarColor: avatarColorForUid(profile.uid),
    wellnessColor: wellnessColorFromScore(score),
    isCurrentUser: isSelf,
    isAdmin: profile.isAdmin,
    presenceLabel: FamilyPresence.label(
      lastActiveAt: profile.lastActiveAt,
      isCurrentUser: isSelf,
      currentUserAppActive: currentUserAppActive,
    ),
    isOnline: online,
    photoUrl: profile.profilePhotoUrl,
  );
}
