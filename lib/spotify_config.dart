import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'openai_env_loader.dart' if (dart.library.io) 'openai_env_loader_io.dart'
    as env_loader;

String? _clientIdFromBundledLocal;
String? _clientSecretFromBundledLocal;
String? _clientIdFromRootFile;
String? _clientSecretFromRootFile;

String? _parseEnvKey(String content, String key) {
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

void _applyFromEnvContent(String content) {
  _clientIdFromBundledLocal ??= _parseEnvKey(content, 'SPOTIFY_CLIENT_ID');
  _clientSecretFromBundledLocal ??=
      _parseEnvKey(content, 'SPOTIFY_CLIENT_SECRET');
}

/// Loads Spotify API credentials. Call [initOpenAiEnv] first (loads dotenv).
Future<void> initSpotifyEnv() async {
  try {
    final raw = await rootBundle.loadString('assets/spotify.local.env');
    _applyFromEnvContent(raw);
  } catch (e, st) {
    debugPrint('[CareSignal][Spotify] assets/spotify.local.env skipped: $e');
    debugPrint('$st');
  }
  try {
    final raw = await rootBundle.loadString('assets/openai.local.env');
    _applyFromEnvContent(raw);
  } catch (_) {
    // Optional combined local env file.
  }
  try {
    final extra = await env_loader.loadRootOpenAiEnv();
    if (extra != null) {
      final id = extra['SPOTIFY_CLIENT_ID']?.trim();
      final secret = extra['SPOTIFY_CLIENT_SECRET']?.trim();
      if (id != null && id.isNotEmpty) _clientIdFromRootFile = id;
      if (secret != null && secret.isNotEmpty) {
        _clientSecretFromRootFile = secret;
      }
    }
  } catch (e, st) {
    debugPrint('[CareSignal][Spotify] root .env merge failed: $e');
    debugPrint('$st');
  }
}

String? get spotifyClientIdOrNull {
  const fromDefine = String.fromEnvironment('SPOTIFY_CLIENT_ID');
  if (fromDefine.isNotEmpty) return fromDefine.trim();

  final bundled = _clientIdFromBundledLocal?.trim();
  if (bundled != null && bundled.isNotEmpty) return bundled;

  final fromFile = _clientIdFromRootFile?.trim();
  if (fromFile != null && fromFile.isNotEmpty) return fromFile;

  try {
    if (dotenv.isInitialized) {
      final fromDot = dotenv.env['SPOTIFY_CLIENT_ID']?.trim();
      if (fromDot != null && fromDot.isNotEmpty) return fromDot;
    }
  } catch (_) {}
  return null;
}

String? get spotifyClientSecretOrNull {
  const fromDefine = String.fromEnvironment('SPOTIFY_CLIENT_SECRET');
  if (fromDefine.isNotEmpty) return fromDefine.trim();

  final bundled = _clientSecretFromBundledLocal?.trim();
  if (bundled != null && bundled.isNotEmpty) return bundled;

  final fromFile = _clientSecretFromRootFile?.trim();
  if (fromFile != null && fromFile.isNotEmpty) return fromFile;

  try {
    if (dotenv.isInitialized) {
      final fromDot = dotenv.env['SPOTIFY_CLIENT_SECRET']?.trim();
      if (fromDot != null && fromDot.isNotEmpty) return fromDot;
    }
  } catch (_) {}
  return null;
}

bool get isSpotifyApiConfigured {
  final id = spotifyClientIdOrNull;
  final secret = spotifyClientSecretOrNull;
  return id != null &&
      id.isNotEmpty &&
      secret != null &&
      secret.isNotEmpty;
}
