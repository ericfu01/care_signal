import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Writes `lastActiveAt` on the signed-in user while the app is in use.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  static bool appInForeground = true;

  Timer? _heartbeat;
  StreamSubscription<User?>? _authSub;
  bool _observerRegistered = false;

  void attach() {
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        startHeartbeat();
      } else {
        stopHeartbeat();
      }
    });
    if (FirebaseAuth.instance.currentUser != null) {
      startHeartbeat();
    }
  }

  void detach() {
    _authSub?.cancel();
    _authSub = null;
    stopHeartbeat();
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
  }

  void startHeartbeat() {
    unawaited(ping());
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) => ping(),
    );
  }

  void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appInForeground = state == AppLifecycleState.resumed;
    if (appInForeground) {
      unawaited(ping());
    }
  }

  Future<void> ping() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !appInForeground) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'lastActiveAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('[CareSignal][Presence] ping failed: $e');
      debugPrint('$st');
    }
  }
}
