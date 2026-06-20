import 'package:cloud_firestore/cloud_firestore.dart';

import 'transport_coverage_config.dart';

/// Loads transport coverage from Firestore with a local fallback.
class TransportCoverageService {
  TransportCoverageService._();

  static final TransportCoverageService instance = TransportCoverageService._();

  static const _docPath = 'config/transport_coverage';

  TransportCoverageConfig? _cached;

  Future<TransportCoverageConfig> loadConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;

    try {
      final snap = await FirebaseFirestore.instance.doc(_docPath).get();
      if (snap.exists) {
        final config = TransportCoverageConfig.fromMap(snap.data() ?? {});
        if (config.zipPrefixes.isNotEmpty || config.zipCodes.isNotEmpty) {
          _cached = config;
          return config;
        }
      }
    } catch (_) {}

    _cached = TransportCoverageConfig.defaultBayArea;
    return _cached!;
  }

  Stream<TransportCoverageConfig> watchConfig() {
    return FirebaseFirestore.instance.doc(_docPath).snapshots().map((snap) {
      if (snap.exists) {
        final config = TransportCoverageConfig.fromMap(snap.data() ?? {});
        if (config.zipPrefixes.isNotEmpty || config.zipCodes.isNotEmpty) {
          _cached = config;
          return config;
        }
      }
      _cached = TransportCoverageConfig.defaultBayArea;
      return _cached!;
    });
  }

  void clearCache() => _cached = null;
}
