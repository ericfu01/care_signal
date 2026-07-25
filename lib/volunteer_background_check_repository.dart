import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'volunteer_background_check.dart';

class VolunteerBackgroundCheckApplication {
  const VolunteerBackgroundCheckApplication({
    required this.legalFirstName,
    required this.legalLastName,
    required this.dateOfBirth,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.zip,
  });

  final String legalFirstName;
  final String legalLastName;
  final DateTime dateOfBirth;
  final String streetAddress;
  final String city;
  final String state;
  final String zip;
}

class VolunteerBackgroundCheckRepository {
  VolunteerBackgroundCheckRepository._();

  static final VolunteerBackgroundCheckRepository instance =
      VolunteerBackgroundCheckRepository._();

  static const _applicationDocId = 'current';

  Future<String?> _uid() async => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _applicationRef(String uid) =>
      _userRef(uid).collection('background_check_application').doc(_applicationDocId);

  Future<VolunteerBackgroundCheckApplication?> fetchCurrentApplication([
    String? forUid,
  ]) async {
    final uid = forUid ?? await _uid();
    if (uid == null) return null;
    final snap = await _applicationRef(uid).get();
    if (!snap.exists) return null;
    final data = snap.data() ?? {};
    final dob = data['dateOfBirth'];
    if (dob is! Timestamp) return null;
    return VolunteerBackgroundCheckApplication(
      legalFirstName: (data['legalFirstName'] as String?)?.trim() ?? '',
      legalLastName: (data['legalLastName'] as String?)?.trim() ?? '',
      dateOfBirth: dob.toDate(),
      streetAddress: (data['streetAddress'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      state: (data['state'] as String?)?.trim() ?? '',
      zip: (data['zip'] as String?)?.trim() ?? '',
    );
  }

  Stream<VolunteerBackgroundCheckApplication?> watchCurrentApplication(
    String uid,
  ) {
    return _applicationRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data() ?? {};
      final dob = data['dateOfBirth'];
      if (dob is! Timestamp) return null;
      return VolunteerBackgroundCheckApplication(
        legalFirstName: (data['legalFirstName'] as String?)?.trim() ?? '',
        legalLastName: (data['legalLastName'] as String?)?.trim() ?? '',
        dateOfBirth: dob.toDate(),
        streetAddress: (data['streetAddress'] as String?)?.trim() ?? '',
        city: (data['city'] as String?)?.trim() ?? '',
        state: (data['state'] as String?)?.trim() ?? '',
        zip: (data['zip'] as String?)?.trim() ?? '',
      );
    });
  }

  Future<void> submitApplication(VolunteerBackgroundCheckApplication application) async {
    final uid = await _uid();
    if (uid == null) {
      throw StateError('Sign in to submit volunteer screening.');
    }

    final first = application.legalFirstName.trim();
    final last = application.legalLastName.trim();
    final street = application.streetAddress.trim();
    final city = application.city.trim();
    final state = application.state.trim().toUpperCase();
    final zip = application.zip.trim();

    if (first.isEmpty || last.isEmpty) {
      throw StateError('Enter your legal first and last name.');
    }
    if (street.isEmpty || city.isEmpty || state.isEmpty || zip.isEmpty) {
      throw StateError('Enter your full home address.');
    }
    if (zip.length < 5) {
      throw StateError('Enter a valid ZIP code.');
    }

    final age = _ageYears(application.dateOfBirth, DateTime.now());
    if (age < 18) {
      throw StateError('Volunteers must be at least 18 years old.');
    }

    final batch = FirebaseFirestore.instance.batch();
    batch.set(_applicationRef(uid), {
      'legalFirstName': first,
      'legalLastName': last,
      'dateOfBirth': Timestamp.fromDate(
        DateTime(
          application.dateOfBirth.year,
          application.dateOfBirth.month,
          application.dateOfBirth.day,
        ),
      ),
      'streetAddress': street,
      'city': city,
      'state': state,
      'zip': zip,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _userRef(uid),
      {
        'backgroundCheckStatus': VolunteerBackgroundCheckStatus.pending,
        'backgroundCheckSubmittedAt': FieldValue.serverTimestamp(),
        'backgroundCheckNote': FieldValue.delete(),
        'backgroundCheckReviewedAt': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  int _ageYears(DateTime birthDate, DateTime onDate) {
    var years = onDate.year - birthDate.year;
    final birthdayThisYear = DateTime(
      onDate.year,
      birthDate.month,
      birthDate.day,
    );
    if (onDate.isBefore(birthdayThisYear)) years--;
    return years;
  }
}
