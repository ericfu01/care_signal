import 'package:cloud_firestore/cloud_firestore.dart';

import 'family_check_in_loader.dart';

class PartnerHistoryPoint {
  const PartnerHistoryPoint({
    required this.dayKey,
    required this.score,
    this.topStressSources = const [],
    this.updatedAt,
  });

  final String dayKey;
  final int score;
  final List<String> topStressSources;
  final DateTime? updatedAt;

  DateTime? get date {
    final parts = dayKey.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  factory PartnerHistoryPoint.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final stress = (data['topStressSources'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return PartnerHistoryPoint(
      dayKey: (data['dayKey'] as String?)?.trim().isNotEmpty == true
          ? (data['dayKey'] as String).trim()
          : doc.id,
      score: (data['score'] as num?)?.round() ?? 0,
      topStressSources: stress,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  DailyWellnessPoint toDailyWellnessPoint() {
    final d = date ?? DateTime.now();
    return DailyWellnessPoint(
      date: d,
      averageScore: score.toDouble(),
    );
  }
}

class PartnerShareRepository {
  PartnerShareRepository._();

  static final PartnerShareRepository instance = PartnerShareRepository._();

  CollectionReference<Map<String, dynamic>> get _shares =>
      FirebaseFirestore.instance.collection('partner_shares');

  Stream<List<PartnerHistoryPoint>> watchHistory(
    String familyUid, {
    int limit = 30,
  }) {
    return _shares
        .doc(familyUid)
        .collection('history')
        .orderBy('dayKey', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final points = snap.docs.map(PartnerHistoryPoint.fromDoc).toList();
      // Chart expects chronological order (oldest → newest).
      return points.reversed.toList();
    });
  }

  Future<void> deleteShareAndHistory(String familyUid) async {
    final history = await _shares.doc(familyUid).collection('history').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in history.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_shares.doc(familyUid));
    await batch.commit();
  }
}
