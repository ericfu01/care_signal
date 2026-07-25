import 'package:cloud_firestore/cloud_firestore.dart';

import 'scheduled_event.dart';

/// Firestore `community_events/{eventId}`.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.isOnline,
    required this.timeDisplay,
    this.description,
    this.published = true,
    this.cancelled = false,
    this.signupCount = 0,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final bool isOnline;
  final String timeDisplay;
  final String? description;
  final bool published;
  final bool cancelled;
  final int signupCount;

  String get monthAbbrev {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[startsAt.month - 1];
  }

  String get day => '${startsAt.day}';

  bool get isUpcoming => startsAt.isAfter(DateTime.now());

  bool get isVisibleToFamilies => published && !cancelled && isUpcoming;

  ScheduledEvent toScheduledEvent({int? familiesSignedUp}) {
    return ScheduledEvent(
      id: id,
      monthAbbrev: monthAbbrev,
      day: day,
      title: title,
      isOnline: isOnline,
      timeDisplay: timeDisplay,
      familiesSignedUp: familiesSignedUp ?? signupCount,
    );
  }

  factory CommunityEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CommunityEvent(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? doc.id,
      startsAt: (data['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] as bool? ?? true,
      timeDisplay: (data['timeDisplay'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim(),
      published: data['published'] as bool? ?? true,
      cancelled: data['cancelled'] as bool? ?? false,
      signupCount: (data['signupCount'] as num?)?.round() ?? 0,
    );
  }

  Map<String, dynamic> toCreateMap({
    required String createdByUid,
  }) =>
      {
        'title': title,
        'startsAt': Timestamp.fromDate(startsAt),
        'isOnline': isOnline,
        'timeDisplay': timeDisplay,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'published': published,
        'cancelled': false,
        'signupCount': 0,
        'createdByUid': createdByUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'title': title,
        'startsAt': Timestamp.fromDate(startsAt),
        'isOnline': isOnline,
        'timeDisplay': timeDisplay,
        'description':
            description != null && description!.isNotEmpty ? description : FieldValue.delete(),
        'published': published,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class CommunityEventSignup {
  const CommunityEventSignup({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.familyCount,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String? phone;
  final int familyCount;
  final DateTime? createdAt;

  factory CommunityEventSignup.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CommunityEventSignup(
      uid: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Guest',
      email: (data['email'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim(),
      familyCount: (data['familyCount'] as num?)?.round() ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
