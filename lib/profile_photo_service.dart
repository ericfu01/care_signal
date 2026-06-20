import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

/// Uploads profile photos to Firebase Storage and saves the URL on `users/{uid}`.
class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  static const _uploadTimeout = Duration(seconds: 30);

  String get _bucket {
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw StateError('Firebase Storage bucket is not configured.');
    }
    return bucket;
  }

  String _objectPath(String uid) => 'profile_photos/$uid.jpg';

  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('Photo file is empty.');
    }
    if (bytes.length > 4 * 1024 * 1024) {
      throw StateError(
        'Photo is too large (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB). '
        'Try a smaller image.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to upload a profile photo.');
    }
    if (user.uid != uid) {
      throw StateError('Profile photo uid mismatch.');
    }

    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Could not get auth token. Try signing out and back in.');
    }
    final objectPath = _objectPath(uid);
    final bucket = _bucket;

    if (kDebugMode) {
      debugPrint(
        '[ProfilePhoto] Uploading ${bytes.length} bytes to '
        'gs://$bucket/$objectPath',
      );
    }

    late final String url;
    try {
      url = await _uploadViaRestApi(
        bucket: bucket,
        objectPath: objectPath,
        bytes: bytes,
        idToken: idToken,
      );
    } catch (restError) {
      if (kDebugMode) {
        debugPrint('[ProfilePhoto] REST upload failed: $restError');
        debugPrint('[ProfilePhoto] Trying Firebase Storage SDK fallback…');
      }
      url = await _uploadViaSdk(
        bucket: bucket,
        objectPath: objectPath,
        bytes: bytes,
      );
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'profilePhotoUrl': url},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw StateError(
        'Photo uploaded but profile save failed (${e.code}): '
        '${e.message ?? 'unknown error'}',
      );
    }

    if (kDebugMode) {
      debugPrint('[ProfilePhoto] Saved profilePhotoUrl for $uid');
    }
    return url;
  }

  /// Direct HTTP upload — avoids iOS SDK hangs seen with [Reference.putFile].
  Future<String> _uploadViaRestApi({
    required String bucket,
    required String objectPath,
    required Uint8List bytes,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
      '?uploadType=media&name=${Uri.encodeComponent(objectPath)}',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Firebase $idToken',
            'Content-Type': 'image/jpeg',
          },
          body: bytes,
        )
        .timeout(_uploadTimeout);

    if (response.statusCode != 200) {
      throw StateError(
        'Storage HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final downloadToken = data['downloadTokens'] as String?;
    final storedName = data['name'] as String? ?? objectPath;
    if (downloadToken == null || downloadToken.isEmpty) {
      throw StateError('Upload succeeded but no download token was returned.');
    }

    final encodedName = Uri.encodeComponent(storedName);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/'
        '$encodedName?alt=media&token=$downloadToken';
  }

  Future<String> _uploadViaSdk({
    required String bucket,
    required String objectPath,
    required Uint8List bytes,
  }) async {
    final storage = FirebaseStorage.instanceFor(
      bucket: bucket,
    );
    final ref = storage.ref().child(objectPath);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = ref.putData(bytes, metadata);

    try {
      await task.timeout(_uploadTimeout);
    } on TimeoutException {
      await task.cancel();
      rethrow;
    }

    if (task.snapshot.state != TaskState.success) {
      throw StateError('SDK upload ended in ${task.snapshot.state}.');
    }

    return ref.getDownloadURL().timeout(_uploadTimeout);
  }

  Future<void> deleteProfilePhoto(String uid) async {
    try {
      await FirebaseStorage.instanceFor(bucket: _bucket)
          .ref()
          .child(_objectPath(uid))
          .delete();
    } catch (_) {}
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'profilePhotoUrl': FieldValue.delete()},
      SetOptions(merge: true),
    );
  }
}
