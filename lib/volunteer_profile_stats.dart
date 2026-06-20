/// Public impact stats stored on `users/{volunteerUid}.volunteerStats`.
class VolunteerProfileStats {
  const VolunteerProfileStats({
    this.completedVisits = 0,
    this.familiesHelped = 0,
  });

  final int completedVisits;
  final int familiesHelped;

  bool get hasActivity => completedVisits > 0 || familiesHelped > 0;

  factory VolunteerProfileStats.fromFirestore(dynamic raw) {
    if (raw is! Map) return const VolunteerProfileStats();
    final map = Map<String, dynamic>.from(raw);
    return VolunteerProfileStats(
      completedVisits: (map['completedVisits'] as num?)?.toInt() ?? 0,
      familiesHelped: (map['familiesHelped'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'completedVisits': completedVisits,
        'familiesHelped': familiesHelped,
      };

  String get summaryLabel {
    if (!hasActivity) return 'New volunteer';
    final familyLabel =
        familiesHelped == 1 ? '1 family helped' : '$familiesHelped families helped';
    if (completedVisits <= familiesHelped) return familyLabel;
    final visitLabel = completedVisits == 1
        ? '1 visit completed'
        : '$completedVisits visits completed';
    return '$familyLabel · $visitLabel';
  }
}
