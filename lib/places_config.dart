import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'openai_env_loader.dart' if (dart.library.io) 'openai_env_loader_io.dart'
    as env_loader;

String? _keyFromBundledLocal;
String? _keyFromRootFile;

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
  _keyFromBundledLocal ??= _parseEnvKey(content, 'GOOGLE_PLACES_API_KEY');
  _keyFromBundledLocal ??= _parseEnvKey(content, 'GOOGLE_MAPS_API_KEY');
}

/// Loads Google Places / Maps API key. Call [initOpenAiEnv] first (loads dotenv).
Future<void> initPlacesEnv() async {
  try {
    final raw = await rootBundle.loadString('assets/places.local.env');
    _applyFromEnvContent(raw);
  } catch (e, st) {
    debugPrint('[CareSignal][Places] assets/places.local.env skipped: $e');
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
      final places = extra['GOOGLE_PLACES_API_KEY']?.trim();
      final maps = extra['GOOGLE_MAPS_API_KEY']?.trim();
      if (places != null && places.isNotEmpty) {
        _keyFromRootFile = places;
      } else if (maps != null && maps.isNotEmpty) {
        _keyFromRootFile = maps;
      }
    }
  } catch (e, st) {
    debugPrint('[CareSignal][Places] root .env merge failed: $e');
    debugPrint('$st');
  }
}

String? get googlePlacesApiKeyOrNull {
  const fromDefine = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  if (fromDefine.isNotEmpty) return fromDefine.trim();

  const fromMapsDefine = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  if (fromMapsDefine.isNotEmpty) return fromMapsDefine.trim();

  final bundled = _keyFromBundledLocal?.trim();
  if (bundled != null && bundled.isNotEmpty) return bundled;

  final fromFile = _keyFromRootFile?.trim();
  if (fromFile != null && fromFile.isNotEmpty) return fromFile;

  try {
    if (dotenv.isInitialized) {
      final fromDot = dotenv.env['GOOGLE_PLACES_API_KEY']?.trim();
      if (fromDot != null && fromDot.isNotEmpty) return fromDot;
      final fromMaps = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
      if (fromMaps != null && fromMaps.isNotEmpty) return fromMaps;
    }
  } catch (_) {}
  return null;
}

bool get isGooglePlacesConfigured {
  final key = googlePlacesApiKeyOrNull;
  return key != null && key.isNotEmpty;
}
