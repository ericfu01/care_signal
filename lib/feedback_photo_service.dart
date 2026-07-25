import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

/// Uploads feedback evidence photos to Firebase Storage.
class FeedbackPhotoService {
  FeedbackPhotoService._();

  static final FeedbackPhotoService instance = FeedbackPhotoService._();

  static const _uploadTimeout = Duration(seconds: 30);
  static const maxPhotos = 3;
  static const maxBytes = 4 * 1024 * 1024;

  String get _bucket {
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw StateError('Firebase Storage bucket is not configured.');
    }
    return bucket;
  }

  String _objectPath({
    required String uid,
    required String feedbackId,
    required int index,
  }) =>
      'feedback_attachments/$uid/$feedbackId/$index.jpg';

  Future<String> uploadFeedbackPhoto({
    required String uid,
    required String feedbackId,
    required int index,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('Photo file is empty.');
    }
    if (bytes.length > maxBytes) {
      throw StateError(
        'Photo is too large (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB). '
        'Try a smaller image.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to attach photos.');
    }
    if (user.uid != uid) {
      throw StateError('Photo upload uid mismatch.');
    }

    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Could not get auth token. Try signing out and back in.');
    }

    final objectPath = _objectPath(
      uid: uid,
      feedbackId: feedbackId,
      index: index,
    );
    final bucket = _bucket;

    try {
      return await _uploadViaRestApi(
        bucket: bucket,
        objectPath: objectPath,
        bytes: bytes,
        idToken: idToken,
      );
    } catch (restError) {
      if (kDebugMode) {
        debugPrint('[FeedbackPhoto] REST upload failed: $restError');
      }
      return _uploadViaSdk(
        bucket: bucket,
        objectPath: objectPath,
        bytes: bytes,
      );
    }
  }

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
    final storage = FirebaseStorage.instanceFor(bucket: bucket);
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
}
