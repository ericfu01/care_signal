import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'openai_env_loader.dart' if (dart.library.io) 'openai_env_loader_io.dart'
    as openai_env_loader;

String? _openAiOverrideFromRootFile;
String? _openAiOverrideFromBundledLocal;

String? _parseEnvLinesForKey(String content, String key) {
  for (final raw in content.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final k = line.substring(0, eq).trim();
    if (k != key) continue;
    var val = line.substring(eq + 1).trim();
    if (val.length >= 2) {
      if ((val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))) {
        val = val.substring(1, val.length - 1);
      }
    }
    final t = val.trim();
    return t.isEmpty ? null : t;
  }
  return null;
}

/// Loads bundled defaults and optional root `.env` (desktop). Call from [main]
/// before reading the key.
Future<void> initOpenAiEnv() async {
  try {
    await dotenv.load(fileName: 'assets/env.defaults');
  } catch (e, st) {
    debugPrint('[CareSignal][OpenAI] assets/env.defaults load failed: $e');
    debugPrint('$st');
  }
  try {
    final raw = await rootBundle.loadString('assets/openai.local.env');
    final key = _parseEnvLinesForKey(raw, 'OPENAI_API_KEY');
    if (key != null && key.isNotEmpty) {
      _openAiOverrideFromBundledLocal = key;
    }
  } catch (e, st) {
    debugPrint('[CareSignal][OpenAI] assets/openai.local.env skipped: $e');
    debugPrint('$st');
  }
  try {
    final extra = await openai_env_loader.loadRootOpenAiEnv();
    final key = extra?['OPENAI_API_KEY']?.trim();
    if (key != null && key.isNotEmpty) {
      _openAiOverrideFromRootFile = key;
    }
  } catch (e, st) {
    debugPrint('[CareSignal][OpenAI] root .env merge failed: $e');
    debugPrint('$st');
  }
}

/// Resolves an optional **local** API key (dev / fallback only). Priority:
/// 1. `--dart-define=OPENAI_API_KEY=...` / `--dart-define-from-file=.env` at build time
/// 2. `assets/openai.local.env` (works on iOS/Android when bundled)
/// 3. Root `.env` (`OPENAI_API_KEY`) when [loadRootOpenAiEnv] runs (desktop `flutter run`)
/// 4. `assets/env.defaults` via flutter_dotenv
///
/// Production preference: signed-in users call the `openAiChatCompletion` Cloud
/// Function so the key stays in Firebase secrets, not the app binary.
String? get openAiApiKeyOrNull {
  const fromDefine = String.fromEnvironment('OPENAI_API_KEY');
  if (fromDefine.isNotEmpty) return fromDefine.trim();

  final fromBundled = _openAiOverrideFromBundledLocal?.trim();
  if (fromBundled != null && fromBundled.isNotEmpty) return fromBundled;

  final fromFile = _openAiOverrideFromRootFile?.trim();
  if (fromFile != null && fromFile.isNotEmpty) return fromFile;

  try {
    if (!dotenv.isInitialized) return null;
    final fromDot = dotenv.env['OPENAI_API_KEY']?.trim();
    if (fromDot != null && fromDot.isNotEmpty) return fromDot;
  } catch (_) {
    return null;
  }
  return null;
}

bool get hasLocalOpenAiKey =>
    openAiApiKeyOrNull != null && openAiApiKeyOrNull!.isNotEmpty;

/// True when AI can be attempted: Cloud Function (signed in) and/or local key.
bool get isOpenAiConfigured {
  if (hasLocalOpenAiKey) return true;
  try {
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}
