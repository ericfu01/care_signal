import 'package:cloud_firestore/cloud_firestore.dart';

import 'account_type.dart';
import 'family_models.dart';
import 'family_repository.dart';
import 'request_duration.dart';
import 'support_catalog.dart';
import 'volunteer_availability.dart';

/// A live volunteer account matched to a support lane.
class VolunteerMatch {
  const VolunteerMatch({
    required this.catalogId,
    required this.volunteerUid,
    required this.displayName,
    required this.lane,
  });

  final String catalogId;
  final String volunteerUid;
  final String displayName;
  final CatalogVolunteer lane;
}

/// Catalog lane plus an optional registered volunteer profile.
class VolunteerCardModel {
  const VolunteerCardModel({
    required this.lane,
    this.profile,
  });

  final CatalogVolunteer lane;
  final UserProfile? profile;

  String get catalogId => lane.id;
  String get displayName => profile?.displayName ?? lane.role;
  bool get isRegistered => profile != null;
  bool get isAvailableNow => profile?.isVolunteerAvailableNow() ?? false;
}

/// One service lane and the volunteers who have signed up for it.
class VolunteerLaneSection {
  const VolunteerLaneSection({
    required this.lane,
    required this.volunteers,
  });

  final CatalogVolunteer lane;
  final List<VolunteerCardModel> volunteers;
}

/// Finds registered volunteers in Firestore and matches them to support lanes.
class VolunteerMatching {
  VolunteerMatching._();

  static final VolunteerMatching instance = VolunteerMatching._();

  static const respiteCatalogId = 'maria-santos';
  static const transportCatalogId = 'derek-morrison';

  static String? catalogIdForServiceType(String serviceType) {
    switch (serviceType) {
      case 'respite':
        return respiteCatalogId;
      case 'meal':
        return 'aisha-patel';
      case 'transport':
        return transportCatalogId;
      case 'peer':
        return 'james-chen';
      default:
        return null;
    }
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  Stream<Map<String, List<UserProfile>>> watchProfilesByLane() {
    return _users
        .where('accountType', isEqualTo: AccountType.volunteer)
        .snapshots()
        .map(_groupProfilesByLane);
  }

  Stream<int> watchAvailableVolunteerCount() {
    return watchProfilesByLane().map(countAvailable);
  }

  Map<String, List<UserProfile>> _groupProfilesByLane(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final byLane = <String, List<UserProfile>>{};
    for (final doc in snap.docs) {
      final profile = UserProfile.fromDoc(doc);
      if (!profile.backgroundCheckApproved) continue;
      final laneId = profile.volunteerCatalogId;
      if (laneId == null || laneId.isEmpty) continue;
      byLane.putIfAbsent(laneId, () => []).add(profile);
    }
    for (final profiles in byLane.values) {
      profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return byLane;
  }

  int countAvailable(Map<String, List<UserProfile>> byLane) {
    final now = DateTime.now();
    var count = 0;
    for (final profiles in byLane.values) {
      for (final profile in profiles) {
        if (profile.isVolunteerAvailableNow(now)) count++;
      }
    }
    return count;
  }

  int countRegisteredForLane(
    String catalogId,
    Map<String, List<UserProfile>> byLane,
  ) =>
      byLane[catalogId]?.length ?? 0;

  List<VolunteerCardModel> liveVolunteerCards(
    Map<String, List<UserProfile>> byLane, {
    String? catalogId,
  }) {
    final cards = <VolunteerCardModel>[];
    final lanes = catalogId == null
        ? SupportCatalog.volunteers
        : [SupportCatalog.laneById(catalogId)].whereType<CatalogVolunteer>();

    for (final lane in lanes) {
      for (final profile in byLane[lane.id] ?? const []) {
        cards.add(VolunteerCardModel(lane: lane, profile: profile));
      }
    }

    cards.sort((a, b) {
      if (a.isAvailableNow != b.isAvailableNow) {
        return a.isAvailableNow ? -1 : 1;
      }
      final laneOrder = SupportCatalog.volunteers
          .indexWhere((lane) => lane.id == a.catalogId)
          .compareTo(
            SupportCatalog.volunteers.indexWhere((lane) => lane.id == b.catalogId),
          );
      if (laneOrder != 0) return laneOrder;
      return a.displayName.compareTo(b.displayName);
    });
    return cards;
  }

  List<VolunteerLaneSection> groupedLiveVolunteers(
    Map<String, List<UserProfile>> byLane,
  ) {
    final sections = <VolunteerLaneSection>[];
    for (final lane in SupportCatalog.volunteers) {
      final profiles = byLane[lane.id] ?? const [];
      if (profiles.isEmpty) continue;
      sections.add(
        VolunteerLaneSection(
          lane: lane,
          volunteers: profiles
              .map((profile) => VolunteerCardModel(lane: lane, profile: profile))
              .toList(),
        ),
      );
    }
    return sections;
  }

  Future<VolunteerMatch?> findAvailableVolunteer(
    String catalogId, {
    DateTime? windowStart,
    int? durationMinutes,
  }) async {
    final lane = SupportCatalog.laneById(catalogId);
    if (lane == null) return null;

    try {
      final snap = await _users
          .where('accountType', isEqualTo: AccountType.volunteer)
          .where('volunteerCatalogId', isEqualTo: catalogId)
          .where('volunteerOnline', isEqualTo: true)
          .limit(20)
          .get();

      final now = DateTime.now();
      final start = windowStart ?? now;
      final duration = durationMinutes ?? RequestDuration.defaultForService(
            catalogId == transportCatalogId ? 'transport' : 'respite',
          );
      final candidates = snap.docs
          .map(UserProfile.fromDoc)
          .where((profile) => profile.backgroundCheckApproved)
          .where(
            (profile) => profile.isVolunteerAvailableForWindow(
              start: start,
              durationMinutes: duration,
            ),
          )
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      if (candidates.isEmpty) return null;

      final profile = candidates.first;
      return VolunteerMatch(
        catalogId: catalogId,
        volunteerUid: profile.uid,
        displayName: profile.displayName,
        lane: lane,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns a user-facing message when the requested window is unavailable.
  Future<String?> scheduleConflictMessage({
    required String catalogId,
    required DateTime start,
    required int durationMinutes,
    String? volunteerUid,
  }) async {
    if (volunteerUid != null && volunteerUid.isNotEmpty) {
      final profile =
          await FamilyRepository.instance.getUserProfile(volunteerUid);
      if (profile == null) return null;
      return _conflictMessageForProfile(profile, start, durationMinutes);
    }

    try {
      final snap = await _users
          .where('accountType', isEqualTo: AccountType.volunteer)
          .where('volunteerCatalogId', isEqualTo: catalogId)
          .limit(20)
          .get();
      final profiles = snap.docs.map(UserProfile.fromDoc).toList();
      if (profiles.isEmpty) return null;

      final available = profiles.any(
        (profile) => profile.isVolunteerAvailableForWindow(
          start: start,
          durationMinutes: durationMinutes,
        ),
      );
      if (available) return null;

      return _laneConflictMessage(profiles, start, durationMinutes);
    } catch (_) {
      return null;
    }
  }

  Future<List<DateTime>> scheduleSuggestions({
    required String catalogId,
    required DateTime start,
    required int durationMinutes,
    String? volunteerUid,
    int maxSuggestions = 3,
  }) async {
    if (volunteerUid != null && volunteerUid.isNotEmpty) {
      final profile =
          await FamilyRepository.instance.getUserProfile(volunteerUid);
      if (profile == null) return const [];
      return VolunteerAvailability.findNextAvailableStarts(
        schedule: profile.volunteerSchedule(),
        blocks: profile.availabilityBlocks.withoutExpired(start),
        searchFrom: start,
        durationMinutes: durationMinutes,
        maxSuggestions: maxSuggestions,
      );
    }

    try {
      final snap = await _users
          .where('accountType', isEqualTo: AccountType.volunteer)
          .where('volunteerCatalogId', isEqualTo: catalogId)
          .limit(20)
          .get();
      final profiles = snap.docs.map(UserProfile.fromDoc).toList();
      if (profiles.isEmpty) return const [];

      final candidates = <DateTime>[];
      for (final profile in profiles) {
        candidates.addAll(
          VolunteerAvailability.findNextAvailableStarts(
            schedule: profile.volunteerSchedule(),
            blocks: profile.availabilityBlocks.withoutExpired(start),
            searchFrom: start,
            durationMinutes: durationMinutes,
            maxSuggestions: 2,
          ),
        );
      }

      candidates.sort();
      final unique = <DateTime>[];
      for (final time in candidates) {
        if (unique.any((u) => u.difference(time).inMinutes.abs() < 30)) {
          continue;
        }
        unique.add(time);
        if (unique.length >= maxSuggestions) break;
      }
      return unique;
    } catch (_) {
      return const [];
    }
  }

  String _laneConflictMessage(
    List<UserProfile> profiles,
    DateTime requestedStart,
    int durationMinutes,
  ) {
    final candidates = <DateTime>[];
    for (final profile in profiles) {
      candidates.addAll(
        VolunteerAvailability.findNextAvailableStarts(
          schedule: profile.volunteerSchedule(),
          blocks: profile.availabilityBlocks.withoutExpired(requestedStart),
          searchFrom: requestedStart,
          durationMinutes: durationMinutes,
          maxSuggestions: 2,
        ),
      );
    }

    candidates.sort();
    final unique = <DateTime>[];
    for (final time in candidates) {
      if (unique.any((u) => u.difference(time).inMinutes.abs() < 30)) continue;
      unique.add(time);
      if (unique.length >= 3) break;
    }

    if (unique.isEmpty) {
      return 'No volunteers are available at that time. '
          'Please pick another date or time.';
    }

    final labels =
        unique.map(VolunteerAvailability.formatSuggestion).join(', ');
    return 'No volunteers are available at that time. Try: $labels.';
  }

  String? _conflictMessageForProfile(
    UserProfile profile,
    DateTime start,
    int durationMinutes,
  ) {
    final message = VolunteerAvailability.conflictMessage(
      volunteerName: profile.displayName,
      schedule: profile.volunteerSchedule(),
      blocks: profile.availabilityBlocks,
      requestedStart: start,
      durationMinutes: durationMinutes,
    );
    return message.isEmpty ? null : message;
  }

  Future<VolunteerCardModel?> findTransportVolunteerCard() async {
    final match = await findAvailableVolunteer(transportCatalogId);
    final lane = SupportCatalog.laneById(transportCatalogId);
    if (lane == null) return null;
    if (match == null) return null;
    final profile =
        await FamilyRepository.instance.getUserProfile(match.volunteerUid);
    if (profile == null) return null;
    return VolunteerCardModel(lane: lane, profile: profile);
  }

  String laneFallbackName(String catalogId) {
    return SupportCatalog.laneById(catalogId)?.role ?? 'Volunteer';
  }
}
