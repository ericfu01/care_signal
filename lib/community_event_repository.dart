import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'community_event_models.dart';

class CommunityEventRepository {
  CommunityEventRepository._();

  static final CommunityEventRepository instance = CommunityEventRepository._();

  CollectionReference<Map<String, dynamic>> get _events =>
      FirebaseFirestore.instance.collection('community_events');

  Stream<List<CommunityEvent>> watchUpcomingPublishedEvents() {
    return _events
        .where('published', isEqualTo: true)
        .orderBy('startsAt')
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      return snap.docs
          .map(CommunityEvent.fromDoc)
          .where((event) => event.startsAt.isAfter(now))
          .toList();
    });
  }

  Stream<CommunityEvent?> watchFeaturedEvent() {
    return watchUpcomingPublishedEvents().map(
      (events) => events.isEmpty ? null : events.first,
    );
  }

  Stream<List<CommunityEvent>> watchAllEventsForStaff() {
    return _events.orderBy('startsAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(CommunityEvent.fromDoc).toList(),
        );
  }

  Stream<List<CommunityEventSignup>> watchSignups(String eventId) {
    return _events
        .doc(eventId)
        .collection('signups')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityEventSignup.fromDoc).toList());
  }

  Future<bool> hasSignup(String eventId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _events.doc(eventId).collection('signups').doc(uid).get();
    return snap.exists;
  }

  Future<void> submitSignup({
    required String eventId,
    required String eventTitle,
    required String name,
    required String email,
    String? phone,
    required int familyCount,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to sign up.');

    final signupRef = _events.doc(eventId).collection('signups').doc(uid);
    final existing = await signupRef.get();
    await signupRef.set({
      'eventId': eventId,
      'eventTitle': eventTitle,
      'name': name.trim(),
      'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'familyCount': familyCount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!existing.exists) {
      await _events.doc(eventId).update({
        'signupCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('event_signups')
        .doc(eventId)
        .set({
      'eventId': eventId,
      'eventTitle': eventTitle,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone?.trim(),
      'familyCount': familyCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createEvent({
    required String title,
    required DateTime startsAt,
    required bool isOnline,
    required String timeDisplay,
    String? description,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to create events.');

    final event = CommunityEvent(
      id: '',
      title: title,
      startsAt: startsAt,
      isOnline: isOnline,
      timeDisplay: timeDisplay,
      description: description,
    );
    final ref = _events.doc();
    await ref.set(event.toCreateMap(createdByUid: uid));
    return ref.id;
  }

  Future<CommunityEvent?> fetchFeaturedEvent() async {
    final snap = await _events
        .where('published', isEqualTo: true)
        .orderBy('startsAt')
        .limit(12)
        .get();
    final now = DateTime.now();
    for (final doc in snap.docs) {
      final event = CommunityEvent.fromDoc(doc);
      if (event.startsAt.isAfter(now)) return event;
    }
    return null;
  }

  Future<void> setPublished({
    required String eventId,
    required bool published,
  }) async {
    await _events.doc(eventId).update({
      'published': published,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
