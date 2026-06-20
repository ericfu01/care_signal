import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'check_in_reminder_service.dart';
import 'daily_check_in_page.dart';
import 'family_chat_page.dart';
import 'notification_background.dart';
import 'notification_navigation.dart';
import 'volunteer_home_page.dart';

/// Registers FCM tokens, shows foreground alerts, and routes notification taps.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _androidChannelId = 'family_messages';
  static const _androidChannelName = 'Family messages';
  static const _volunteerChannelId = 'volunteer_requests';
  static const _volunteerChannelName = 'Volunteer requests';
  static const _checkInChannelId = CheckInReminderService.androidChannelId;
  static const _checkInChannelName = CheckInReminderService.androidChannelName;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _currentToken;
  bool _initialized = false;

  void attach({required GlobalKey<NavigatorState> navigatorKey}) {
    _navigatorKey = navigatorKey;
    unawaited(_ensureInitialized());
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(_syncTokenForUser());
        unawaited(_ensureInitialized().then((_) {
          return CheckInReminderService.instance.syncSchedule(_local);
        }));
      } else {
        _currentToken = null;
        unawaited(CheckInReminderService.instance.cancel(_local));
      }
    });
    if (FirebaseAuth.instance.currentUser != null) {
      unawaited(_syncTokenForUser());
    }
  }

  void detach() {
    _authSub?.cancel();
    _authSub = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    final launchDetails = await _local.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final response = launchDetails?.notificationResponse;
      if (response != null) {
        _onLocalNotificationTapped(response);
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _androidChannelId,
              _androidChannelName,
              description: 'Alerts when a family member sends you a message',
              importance: Importance.high,
            ),
          );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _volunteerChannelId,
              _volunteerChannelName,
              description: 'Alerts for volunteer support requests',
              importance: Importance.high,
            ),
          );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _checkInChannelId,
              _checkInChannelName,
              description:
                  'Reminds you to complete your daily wellness check-in',
              importance: Importance.defaultImportance,
            ),
          );
    }

    await _requestPermission();
    await _requestLocalNotificationPermission();

    if (FirebaseAuth.instance.currentUser != null) {
      unawaited(CheckInReminderService.instance.syncSchedule(_local));
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _tokenRefreshSub ??= _messaging.onTokenRefresh.listen((token) {
      unawaited(_saveToken(token));
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _scheduleNavigation(initial.data);
    }
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) return;
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e, st) {
      debugPrint('[CareSignal][Notifications] permission failed: $e');
      debugPrint('$st');
    }
  }

  Future<bool> _requestLocalNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final granted = await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        return granted ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _local
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return granted ?? false;
      }
    } catch (e, st) {
      debugPrint(
        '[CareSignal][Notifications] local permission failed: $e',
      );
      debugPrint('$st');
    }
    return true;
  }

  Future<CheckInReminderSettings> getCheckInReminderSettings() =>
      CheckInReminderService.instance.loadSettings();

  Future<bool> updateCheckInReminderSettings(
    CheckInReminderSettings settings,
  ) async {
    await _ensureInitialized();
    if (settings.enabled) {
      final granted = await _requestLocalNotificationPermission();
      if (!granted) return false;
    }
    await CheckInReminderService.instance.saveSettings(settings);
    await CheckInReminderService.instance.syncSchedule(_local);
    return true;
  }

  Future<void> _syncTokenForUser() async {
    if (kIsWeb) return;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apns = await _messaging.getAPNSToken();
        if (kDebugMode) {
          debugPrint(
            '[CareSignal][Notifications] APNs token: '
            '${apns ?? "null — use a physical iPhone with Push enabled"}',
          );
        }
        if (apns == null) {
          return;
        }
      }

      final token = await _messaging.getToken();
      if (kDebugMode && token != null) {
        debugPrint('[CareSignal][Notifications] FCM token: $token');
      }
      if (token != null) {
        await _saveToken(token);
      }
    } catch (e, st) {
      debugPrint('[CareSignal][Notifications] getToken failed: $e');
      debugPrint('$st');
    }
  }

  /// Latest FCM token for Firebase Console “Send test message” (debug).
  Future<String?> getFcmTokenForDebug() async {
    if (kIsWeb) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null) return null;
      }
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final previousToken = _currentToken;
    if (previousToken != null &&
        previousToken != token &&
        previousToken.isNotEmpty) {
      await _deleteTokenDoc(uid, previousToken);
    }

    _currentToken = token;
    final docId = _tokenDocId(token);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(docId)
          .set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _pruneStaleTokens(uid, keepDocId: docId);
    } catch (e, st) {
      debugPrint('[CareSignal][Notifications] save token failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> _deleteTokenDoc(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(_tokenDocId(token))
          .delete();
    } catch (e, st) {
      debugPrint('[CareSignal][Notifications] delete old token failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> _pruneStaleTokens(String uid, {required String keepDocId}) async {
    const maxTokens = 5;
    const maxAge = Duration(days: 90);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .get();
      if (snap.docs.length <= maxTokens) {
        final now = DateTime.now();
        for (final doc in snap.docs) {
          if (doc.id == keepDocId) continue;
          final updated = doc.data()['updatedAt'];
          if (updated is! Timestamp) continue;
          if (now.difference(updated.toDate()) > maxAge) {
            await doc.reference.delete();
          }
        }
        return;
      }

      final sorted = snap.docs.toList()
        ..sort((a, b) {
          final aTime = a.data()['updatedAt'];
          final bTime = b.data()['updatedAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

      for (var i = maxTokens; i < sorted.length; i++) {
        await sorted[i].reference.delete();
      }
    } catch (e, st) {
      debugPrint('[CareSignal][Notifications] prune tokens failed: $e');
      debugPrint('$st');
    }
  }


  static String _tokenDocId(String token) {
    return base64Url.encode(utf8.encode(token)).replaceAll('=', '');
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    final payload = jsonEncode(message.data);
    final type = message.data['type'] as String? ?? '';
    final channelId = NotificationNavigation.isVolunteerRequestType(type)
        ? _volunteerChannelId
        : _androidChannelId;
    final channelName = NotificationNavigation.isVolunteerRequestType(type)
        ? _volunteerChannelName
        : _androidChannelName;
    final channelDescription = NotificationNavigation.isVolunteerRequestType(type)
        ? 'Alerts for volunteer support requests'
        : 'Alerts when a family member sends you a message';
    _local.show(
      id: message.hashCode,
      title: title ?? 'Care Signal',
      body: body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _scheduleNavigation(message.data);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _scheduleNavigation(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('[CareSignal][Notifications] bad payload: $e');
    }
  }

  void _scheduleNavigation(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateFromPayload(data);
    });
  }

  void _navigateFromPayload(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    final type = data['type'] as String? ?? '';
    if (type == 'family_message') {
      final familyId = data['familyId'] as String? ?? '';
      final chatId = data['chatId'] as String? ?? '';
      final otherUid = data['otherUid'] as String? ?? '';
      final otherDisplayName = data['otherDisplayName'] as String? ?? '';
      if (familyId.isEmpty ||
          chatId.isEmpty ||
          otherUid.isEmpty ||
          otherDisplayName.isEmpty) {
        return;
      }
      nav.push(
        MaterialPageRoute<void>(
          builder: (context) => FamilyChatPage(
            familyId: familyId,
            chatId: chatId,
            otherUid: otherUid,
            otherDisplayName: otherDisplayName,
          ),
        ),
      );
      return;
    }

    if (NotificationNavigation.isVolunteerRequestType(type)) {
      final familyUserId = data['familyUserId'] as String? ?? '';
      final requestId = data['requestId'] as String? ?? '';
      if (familyUserId.isNotEmpty && requestId.isNotEmpty) {
        unawaited(
          NotificationNavigation.openVolunteerRequest(
            nav.context,
            familyUserId: familyUserId,
            requestId: requestId,
          ),
        );
      } else {
        nav.push(
          MaterialPageRoute<void>(
            builder: (context) => const VolunteerHomePage(),
          ),
        );
      }
      return;
    }

    if (NotificationNavigation.isFamilyVolunteerRequestType(type)) {
      final requestId = data['requestId'] as String? ?? '';
      unawaited(
        NotificationNavigation.openFamilyVolunteerRequest(
          nav.context,
          requestId: requestId,
        ),
      );
      return;
    }

    if (type == CheckInReminderService.payloadType) {
      nav.push(
        MaterialPageRoute<void>(
          builder: (context) => const DailyCheckInPage(),
        ),
      );
    }
  }

  /// Simulates an incoming family-message push (debug builds).
  Future<void> showDebugFamilyMessageBanner({
    required String title,
    required String body,
    required String familyId,
    required String chatId,
    required String otherUid,
    required String otherDisplayName,
  }) async {
    await _ensureInitialized();
    final data = <String, dynamic>{
      'type': 'family_message',
      'familyId': familyId,
      'chatId': chatId,
      'otherUid': otherUid,
      'otherDisplayName': otherDisplayName,
    };
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription:
              'Alerts when a family member sends you a message',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  /// Call before [FirebaseAuth.signOut] so the token is removed while uid is known.
  Future<void> onSignOut() async {
    await CheckInReminderService.instance.cancel(_local);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    var token = _currentToken;
    if (token == null) {
      try {
        token = await _messaging.getToken();
      } catch (_) {}
    }
    _currentToken = null;
    if (uid != null && token != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fcm_tokens')
            .doc(_tokenDocId(token))
            .delete();
      } catch (e, st) {
        debugPrint('[CareSignal][Notifications] remove token failed: $e');
        debugPrint('$st');
      }
    }
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }
}
