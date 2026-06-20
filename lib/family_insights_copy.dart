/// Builds insight tip strings only from real check-in data — never guesses about
/// family members who have not checked in.
class FamilyInsightsCopy {
  const FamilyInsightsCopy({
    required this.currentUserName,
    required this.memberNames,
    required this.memberScores,
    this.stressSourceCounts = const {},
  });

  final String currentUserName;
  final List<String> memberNames;
  final Map<String, int?> memberScores;
  final Map<String, int> stressSourceCounts;

  /// True when at least one family member has a saved check-in score.
  bool get hasCheckInData =>
      memberScores.values.any((score) => score != null);

  static String firstName(String fullName) {
    final t = fullName.trim();
    if (t.isEmpty) return 'your family';
    return t.split(RegExp(r'\s+')).first;
  }

  List<String> get _others =>
      memberNames.where((n) => n.trim() != currentUserName.trim()).toList();

  /// Rest tip — only names someone who has actually checked in with a low score.
  String restNeededSubtitle() {
    if (!hasCheckInData) {
      return 'Complete check-ins first — then we can spot who may need extra rest.';
    }

    final withScores = memberScores.entries
        .where((e) => e.value != null)
        .toList();
    if (withScores.isEmpty) {
      return 'Mid-week is often tiring — plan short breaks for everyone.';
    }

    withScores.sort((a, b) => a.value!.compareTo(b.value!));
    final lowest = withScores.first;
    if (lowest.value! >= 60) {
      return 'Energy is holding steady — still worth planning rest before mid-week.';
    }

    final who = lowest.key.trim() == currentUserName.trim()
        ? 'Your'
        : "${firstName(lowest.key)}'s";
    return '$who recent check-in looks low — extra rest mid-week may help';
  }

  String greatJobTitle() {
    if (!hasCheckInData) {
      return 'Start with a check-in';
    }

    if (currentUserName.trim().isNotEmpty &&
        memberScores[currentUserName] != null) {
      final score = memberScores[currentUserName]!;
      if (score >= 70) {
        return 'Great job, ${firstName(currentUserName)}!';
      }
      return 'Thanks for checking in, ${firstName(currentUserName)}';
    }

    final ranked = memberScores.entries
        .where((e) => e.value != null)
        .toList()
      ..sort((a, b) => b.value!.compareTo(a.value!));

    if (ranked.isNotEmpty && ranked.first.value! >= 70) {
      return 'Great job, ${firstName(ranked.first.key)}!';
    }
    return 'Thanks for checking in';
  }

  String greatJobSubtitle() {
    if (!hasCheckInData) {
      return 'Tips personalize after someone completes a daily check-in';
    }
    if (memberScores.values.any((s) => s != null && s >= 70)) {
      return 'Consistent check-ins are helping';
    }
    return 'Keep checking in — small steps add up';
  }

  /// Stress / schedule tip — only uses logged stress sources, not fake weekdays.
  String planBufferSubtitle() {
    if (!hasCheckInData) {
      return 'Check in daily to see which stress sources show up most';
    }

    final top = stressSourceCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (top.isEmpty) {
      return 'Note stress sources in check-ins to see patterns here';
    }
    if (top.length == 1) {
      return '${top.first.key} has come up most in your check-ins';
    }
    return '${top.first.key} and ${top[1].key} are your top stress sources lately';
  }

  String participationTitle() {
    if (!hasCheckInData) return 'Waiting for check-ins';
    final activeCount =
        memberScores.values.where((s) => s != null).length;
    if (activeCount <= 1) return 'Getting started';
    return 'Who\'s checking in';
  }

  /// Family dynamics participation blurb.
  String participationBody() {
    final active = memberScores.entries
        .where((e) => e.value != null)
        .map((e) => e.key)
        .toList();

    if (active.isEmpty) {
      if (memberNames.length <= 1) {
        return 'Invite family members to check in together and see participation here.';
      }
      final invitees = _others.map(firstName).take(3).toList();
      if (invitees.length == 1) {
        return 'Encourage ${invitees.first} to complete a check-in this week.';
      }
      return 'Encourage ${invitees.join(', ')} to complete check-ins this week.';
    }

    active.sort((a, b) {
      final sa = memberScores[a] ?? 0;
      final sb = memberScores[b] ?? 0;
      return sb.compareTo(sa);
    });

    final quiet = memberNames.where((n) => !active.contains(n)).toList();

    if (active.length == 1) {
      final only = firstName(active.first);
      if (quiet.isEmpty) {
        return 'Check-ins this week are coming from $only. Keep the momentum going.';
      }
      final quietFirst = quiet.map(firstName).take(2).join(' and ');
      return 'Most check-ins this week came from $only. '
          'Encourage $quietFirst to join in with a shared family goal.';
    }

    final top = active.take(2).map(firstName).toList();
    final leaders = top.length == 2 ? '${top[0]} and ${top[1]}' : top.first;

    if (quiet.isEmpty) {
      return 'Most check-ins this week came from $leaders. '
          'Your family is staying engaged together.';
    }

    return 'Most check-ins this week came from $leaders. '
        'Encourage quieter members with a shared family goal.';
  }
}
