import 'package:cloud_firestore/cloud_firestore.dart';

import 'family_models.dart';

/// One calendar day's average wellness across family check-ins.
class DailyWellnessPoint {
  const DailyWellnessPoint({
    required this.date,
    this.averageScore,
  });

  final DateTime date;
  final double? averageScore;

  bool get hasData => averageScore != null;
}

/// A single saved daily check-in for history views.
class CheckInHistoryEntry {
  const CheckInHistoryEntry({
    required this.id,
    required this.day,
    required this.score,
    this.mood,
    this.energy,
    this.stress,
    this.stressSources = const [],
    this.createdAt,
  });

  final String id;
  final DateTime day;
  final int score;
  final int? mood;
  final int? energy;
  final int? stress;
  final List<String> stressSources;
  final DateTime? createdAt;
}

/// Latest wellness score per family member (from each user's check-ins).
class FamilyCheckInLoader {
  FamilyCheckInLoader._();

  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _dayKey(DateTime date) => dayKey(date);

  static DateTime? _readCheckInDay(Map<String, dynamic> data) {
    final dayKeyValue = data['dayKey'];
    if (dayKeyValue is String && dayKeyValue.isNotEmpty) {
      final parts = dayKeyValue.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    }

    for (final field in ['createdAt', 'date', 'submittedAt']) {
      final value = data[field];
      if (value is Timestamp) {
        final local = value.toDate().toLocal();
        return DateTime(local.year, local.month, local.day);
      }
    }
    return null;
  }

  static int? _readScore(Map<String, dynamic> data) {
    return (data['score'] as num?)?.round();
  }

  static Future<List<Map<String, dynamic>>> _loadCheckInDocs(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_check_ins')
          .orderBy('createdAt', descending: true)
          .limit(180)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('daily_check_ins')
            .limit(180)
            .get();
        return snap.docs.map((d) => d.data()).toList();
      } catch (_) {
        return const [];
      }
    }
  }

  /// Current user's check-ins, newest first (up to [limit]).
  static Future<List<CheckInHistoryEntry>> loadHistoryForUid(
    String uid, {
    int limit = 180,
  }) async {
    if (uid.isEmpty || limit <= 0) return const [];

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_check_ins')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      docs = snap.docs;
    } catch (_) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('daily_check_ins')
            .limit(limit)
            .get();
        docs = snap.docs.toList()
          ..sort((a, b) {
            final da = _readCheckInDay(a.data()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final db = _readCheckInDay(b.data()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });
      } catch (_) {
        return const [];
      }
    }

    final entries = <CheckInHistoryEntry>[];
    for (final doc in docs) {
      final data = doc.data();
      final day = _readCheckInDay(data);
      final score = _readScore(data);
      if (day == null || score == null) continue;

      final sources = (data['stressSources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];

      DateTime? createdAt;
      final createdRaw = data['createdAt'];
      if (createdRaw is Timestamp) {
        createdAt = createdRaw.toDate().toLocal();
      }

      entries.add(
        CheckInHistoryEntry(
          id: doc.id,
          day: day,
          score: score,
          mood: (data['mood'] as num?)?.round(),
          energy: (data['energy'] as num?)?.round(),
          stress: (data['stress'] as num?)?.round(),
          stressSources: sources,
          createdAt: createdAt,
        ),
      );
    }
    return entries;
  }

  /// Average wellness per calendar day for all [members] over the last [dayCount] days.
  static Future<List<DailyWellnessPoint>> dailyFamilyAverages(
    List<UserProfile> members, {
    required int dayCount,
  }) async {
    final uids = members.map((m) => m.uid).where((uid) => uid.isNotEmpty).toList();
    return dailyFamilyAveragesForUids(uids, dayCount: dayCount);
  }

  /// Average wellness per calendar day for [uids] over the last [dayCount] days.
  static Future<List<DailyWellnessPoint>> dailyFamilyAveragesForUids(
    List<String> uids, {
    required int dayCount,
  }) async {
    if (uids.isEmpty || dayCount <= 0) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: dayCount - 1));

    final scoresByDay = <String, List<int>>{
      for (var i = 0; i < dayCount; i++)
        _dayKey(start.add(Duration(days: i))): <int>[],
    };

    await Future.wait(
      uids.map((uid) async {
        final docs = await _loadCheckInDocs(uid);
        for (final data in docs) {
          final day = _readCheckInDay(data);
          final score = _readScore(data);
          if (day == null || score == null) continue;
          if (day.isBefore(start) || day.isAfter(today)) continue;
          scoresByDay[_dayKey(day)]?.add(score);
        }
      }),
    );

    return List.generate(dayCount, (index) {
      final date = start.add(Duration(days: index));
      final scores = scoresByDay[_dayKey(date)] ?? [];
      return DailyWellnessPoint(
        date: date,
        averageScore: scores.isEmpty
            ? null
            : scores.reduce((a, b) => a + b) / scores.length,
      );
    });
  }

  static Future<Map<String, int?>> latestScoresByMemberName(
    List<UserProfile> members,
  ) async {
    final scores = <String, int?>{};
    await Future.wait(
      members.map((member) async {
        try {
          final docs = await _rawDocsForLatestScores(member.uid);
          if (docs.isEmpty) {
            scores[member.displayName] = null;
            return;
          }
          docs.sort((a, b) {
            final da = _readCheckInDay(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = _readCheckInDay(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });
          scores[member.displayName] = _readScore(docs.first);
        } catch (_) {
          scores[member.displayName] = null;
        }
      }),
    );
    return scores;
  }

  /// Up to [limit] recent scores per member (oldest → newest) for AI context.
  static Future<Map<String, List<int>>> recentScoresByMemberName(
    List<UserProfile> members, {
    int limit = 7,
  }) async {
    final history = <String, List<int>>{};
    await Future.wait(
      members.map((member) async {
        try {
          final docs = await _rawDocsForLatestScores(member.uid);
          docs.sort((a, b) {
            final da = _readCheckInDay(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = _readCheckInDay(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });
          final scores = docs
              .take(limit)
              .map(_readScore)
              .whereType<int>()
              .toList();
          history[member.displayName] = scores.reversed.toList();
        } catch (_) {
          history[member.displayName] = [];
        }
      }),
    );
    return history;
  }

  /// Stress sources from each member's most recent check-in.
  static Future<Map<String, List<String>>> latestStressSourcesByMemberName(
    List<UserProfile> members,
  ) async {
    final out = <String, List<String>>{};
    await Future.wait(
      members.map((member) async {
        final latest = await latestCheckInForUid(member.uid);
        out[member.displayName] = latest?.stressSources ?? const <String>[];
      }),
    );
    return out;
  }

  /// Most recent check-in for [uid], or null if none.
  static Future<CheckInHistoryEntry?> latestCheckInForUid(String uid) async {
    if (uid.isEmpty) return null;
    final history = await loadHistoryForUid(uid, limit: 1);
    if (history.isEmpty) return null;
    return history.first;
  }

  static Future<List<Map<String, dynamic>>> _rawDocsForLatestScores(
    String uid,
  ) async =>
      _loadCheckInDocs(uid);

  static Future<DateTime?> latestCheckInDayForUid(String uid) async {
    try {
      final docs = await _rawDocsForLatestScores(uid);
      if (docs.isEmpty) return null;
      docs.sort((a, b) {
        final da = _readCheckInDay(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = _readCheckInDay(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      return _readCheckInDay(docs.first);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, DateTime?>> latestCheckInDayByMemberName(
    List<UserProfile> members,
  ) async {
    final days = <String, DateTime?>{};
    await Future.wait(
      members.map((member) async {
        days[member.displayName] = await latestCheckInDayForUid(member.uid);
      }),
    );
    return days;
  }

  static String formatLastCheckInLabel(DateTime? day) {
    if (day == null) return 'No check-ins yet';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Last check-in: today';
    if (diff == 1) return 'Last check-in: yesterday';
    return 'Last check-in: $diff days ago';
  }

  /// Adds [dayKey] to legacy check-ins that only have [createdAt].
  static Future<int> backfillMissingDayKeys(String uid) async {
    if (uid.isEmpty) return 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_check_ins')
          .limit(180)
          .get();

      var updated = 0;
      WriteBatch? batch;
      var batchOps = 0;

      Future<void> commitBatch() async {
        if (batch == null || batchOps == 0) return;
        await batch!.commit();
        batch = null;
        batchOps = 0;
      }

      for (final doc in snap.docs) {
        final data = doc.data();
        final existing = data['dayKey'];
        if (existing is String && existing.isNotEmpty) continue;

        final day = _readCheckInDay(data);
        if (day == null) continue;

        batch ??= FirebaseFirestore.instance.batch();
        batch!.update(doc.reference, {'dayKey': dayKey(day)});
        updated++;
        batchOps++;
        if (batchOps >= 400) {
          await commitBatch();
        }
      }
      await commitBatch();
      return updated;
    } catch (_) {
      return 0;
    }
  }
}
