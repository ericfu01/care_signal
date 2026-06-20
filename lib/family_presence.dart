import 'package:cloud_firestore/cloud_firestore.dart';

/// How we treat "online now" vs last seen for family members.
class FamilyPresence {
  FamilyPresence._();

  /// Considered online if the app pinged within this window.
  static const Duration onlineThreshold = Duration(minutes: 3);

  static bool isOnline(DateTime? lastActiveAt, [DateTime? now]) {
    if (lastActiveAt == null) return false;
    final n = now ?? DateTime.now();
    return n.difference(lastActiveAt.toLocal()) < onlineThreshold;
  }

  static int countOnline(Iterable<DateTime?> lastActiveTimes) {
    final now = DateTime.now();
    return lastActiveTimes.where((t) => isOnline(t, now)).length;
  }

  /// Short label for lists and avatars.
  static String label({
    required DateTime? lastActiveAt,
    required bool isCurrentUser,
    required bool currentUserAppActive,
  }) {
    if (isCurrentUser && currentUserAppActive) return 'Online';
    if (lastActiveAt == null) return 'No activity yet';
    if (isOnline(lastActiveAt)) return 'Online';
    return 'Seen ${formatLastSeen(lastActiveAt)}';
  }

  static String formatLastSeen(DateTime lastActiveAt) {
    final diff = DateTime.now().difference(lastActiveAt.toLocal());
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final local = lastActiveAt.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  static DateTime? timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
