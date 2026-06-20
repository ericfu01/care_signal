/// Care Signal account roles stored on `users/{uid}.accountType`.
class AccountType {
  AccountType._();

  static const caregiver = 'caregiver';
  static const volunteer = 'volunteer';

  static bool isVolunteer(String? value) => value == volunteer;

  static bool isCaregiver(String? value) =>
      value == null || value.isEmpty || value == caregiver;

  static String label(String? value) =>
      isVolunteer(value) ? 'Volunteer' : 'Caregiver / family';
}
