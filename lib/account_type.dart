/// Care Signal account roles stored on `users/{uid}.accountType`.
class AccountType {
  AccountType._();

  static const caregiver = 'caregiver';
  static const volunteer = 'volunteer';
  static const staff = 'staff';
  static const partner = 'partner';

  /// Legacy value from before volunteer + host were merged. Migrated on login.
  static const legacyPeerGroupHost = 'peer_group_host';

  static bool isVolunteer(String? value) =>
      value == volunteer || value == legacyPeerGroupHost;

  static bool isStaff(String? value) => value == staff;

  static bool isPartner(String? value) => value == partner;

  static bool isLegacyPeerGroupHost(String? value) =>
      value == legacyPeerGroupHost;

  static bool isCaregiver(String? value) =>
      value == null || value.isEmpty || value == caregiver;

  static String label(String? value) {
    if (isVolunteer(value)) return 'Volunteer';
    if (isStaff(value)) return 'Staff';
    if (isPartner(value)) return 'Partner';
    return 'Caregiver / family';
  }
}
