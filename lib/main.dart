import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'openai_config.dart';
import 'notification_service.dart';
import 'presence_service.dart';
import 'spotify_config.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initOpenAiEnv();
  await initSpotifyEnv();
  if (kDebugMode) {
    debugPrint(
      '[CareSignal][OpenAI] '
      '${isOpenAiConfigured ? 'API key configured' : 'API key missing (stub chat)'}',
    );
    debugPrint(
      '[CareSignal][Spotify] '
      '${isSpotifyApiConfigured ? 'API configured' : 'API missing (links only)'}',
    );
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    PresenceService.instance.attach();
    NotificationService.instance.attach(navigatorKey: appNavigatorKey);
  }

  @override
  void dispose() {
    PresenceService.instance.detach();
    NotificationService.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Care Signal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const AuthGate(),
    );
  }
}
