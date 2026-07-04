/// Volunteer safety screening stored on `users/{uid}.backgroundCheckStatus`.
class VolunteerBackgroundCheckStatus {
  VolunteerBackgroundCheckStatus._();

  static const notStarted = 'not_started';
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';

  static String normalize(String? value) {
    if (value == null || value.isEmpty) return notStarted;
    return value;
  }

  static bool isApproved(String? value) => normalize(value) == approved;

  static bool isPending(String? value) => normalize(value) == pending;

  static bool isRejected(String? value) => normalize(value) == rejected;

  static bool blocksVolunteerAccess(String? value) => !isApproved(value);

  static String label(String? value) {
    return switch (normalize(value)) {
      pending => 'Under review',
      approved => 'Approved',
      rejected => 'Not approved',
      _ => 'Not submitted',
    };
  }
}
