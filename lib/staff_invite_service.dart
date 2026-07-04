import 'package:cloud_functions/cloud_functions.dart';

class StaffInviteService {
  StaffInviteService._();

  static final StaffInviteService instance = StaffInviteService._();

  Future<String> createInvite({String? email}) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('createStaffInvite');
    final result = await callable.call<Map<String, dynamic>>({
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    });
    final code = result.data['code'] as String?;
    if (code == null || code.isEmpty) {
      throw StateError('Could not create staff invite.');
    }
    return code;
  }

  Future<void> redeemInvite(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      throw StateError('Enter your staff access code.');
    }
    final callable =
        FirebaseFunctions.instance.httpsCallable('redeemStaffInvite');
    await callable.call<Map<String, dynamic>>({'code': trimmed});
  }
}
