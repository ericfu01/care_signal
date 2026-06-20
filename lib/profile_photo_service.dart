import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads profile photos to Firebase Storage and saves the URL on `users/{uid}`.
class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  Reference _photoRef(String uid) =>
      FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');

  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
  }) async {
    final ref = _photoRef(uid);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'profilePhotoUrl': url},
      SetOptions(merge: true),
    );
    return url;
  }

  Future<void> deleteProfilePhoto(String uid) async {
    try {
      await _photoRef(uid).delete();
    } catch (_) {}
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'profilePhotoUrl': FieldValue.delete()},
      SetOptions(merge: true),
    );
  }
}
