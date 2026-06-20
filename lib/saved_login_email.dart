import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSavedLoginEmailKey = 'saved_login_email';
const _kSavedLoginNameKey = 'saved_login_name';

Future<void> saveRememberedLoginEmail(String email) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedLoginEmailKey, email.trim());
  } catch (e, st) {
    debugPrint('[CareSignal][Prefs] saveRememberedLoginEmail failed: $e');
    debugPrint('$st');
    rethrow;
  }
}

Future<String?> loadRememberedLoginEmail() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSavedLoginEmailKey);
  } catch (e, st) {
    debugPrint('[CareSignal][Prefs] loadRememberedLoginEmail failed: $e');
    debugPrint('$st');
    rethrow;
  }
}

Future<void> saveRememberedLoginName(String fullName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedLoginNameKey, fullName.trim());
  } catch (e, st) {
    debugPrint('[CareSignal][Prefs] saveRememberedLoginName failed: $e');
    debugPrint('$st');
    rethrow;
  }
}

Future<String?> loadRememberedLoginName() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSavedLoginNameKey);
  } catch (e, st) {
    debugPrint('[CareSignal][Prefs] loadRememberedLoginName failed: $e');
    debugPrint('$st');
    rethrow;
  }
}
