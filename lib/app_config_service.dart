import 'package:cloud_firestore/cloud_firestore.dart';

/// App-wide config from Firestore `config/app`.
class AppConfig {
  const AppConfig({
    required this.supportEmail,
    this.inviteHelpUrl,
  });

  static const defaultSupportEmail = 'care.signal.support@example.com';

  final String supportEmail;
  final String? inviteHelpUrl;

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    final email = (data['supportEmail'] as String?)?.trim();
    final helpUrl = (data['inviteHelpUrl'] as String?)?.trim();
    return AppConfig(
      supportEmail:
          email != null && email.isNotEmpty ? email : defaultSupportEmail,
      inviteHelpUrl: helpUrl != null && helpUrl.isNotEmpty ? helpUrl : null,
    );
  }

  static const defaults = AppConfig(supportEmail: defaultSupportEmail);
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
