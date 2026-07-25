import 'package:cloud_firestore/cloud_firestore.dart';

/// App-wide config from Firestore `config/app`.
class AppConfig {
  const AppConfig({
    this.supportEmail,
    this.inviteHelpUrl,
    this.privacyPolicyUrl,
    this.termsOfServiceUrl,
  });

  /// Contact email shown on Help when set in Firestore. Null = use in-app feedback.
  final String? supportEmail;
  final String? inviteHelpUrl;

  /// Optional hosted legal URLs. When set, Profile/Help open these instead of in-app text.
  final String? privacyPolicyUrl;
  final String? termsOfServiceUrl;

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    String? clean(String key) {
      final value = (data[key] as String?)?.trim();
      return value != null && value.isNotEmpty ? value : null;
    }

    return AppConfig(
      supportEmail: clean('supportEmail'),
      inviteHelpUrl: clean('inviteHelpUrl'),
      privacyPolicyUrl: clean('privacyPolicyUrl'),
      termsOfServiceUrl: clean('termsOfServiceUrl'),
    );
  }

  static const defaults = AppConfig();
}

class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  static const _docPath = 'config/app';

  AppConfig? _cached;

  Future<AppConfig> loadConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;

    try {
      final snap = await FirebaseFirestore.instance.doc(_docPath).get();
      if (snap.exists) {
        _cached = AppConfig.fromMap(snap.data() ?? {});
        return _cached!;
      }
    } catch (_) {}

    _cached = AppConfig.defaults;
    return _cached!;
  }

  Stream<AppConfig> watchConfig() {
    return FirebaseFirestore.instance.doc(_docPath).snapshots().map((snap) {
      if (snap.exists) {
        _cached = AppConfig.fromMap(snap.data() ?? {});
        return _cached!;
      }
      _cached = AppConfig.defaults;
      return _cached!;
    });
  }
}
