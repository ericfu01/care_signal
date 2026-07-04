import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_session.dart';

class PartnerShareRecord {
  const PartnerShareRecord({
    required this.familyUid,
    required this.score,
    required this.dayKey,
    required this.topStressSources,
    this.updatedAt,
  });

  final String familyUid;
  final int score;
  final String dayKey;
  final List<String> topStressSources;
  final DateTime? updatedAt;

  factory PartnerShareRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final stress = (data['topStressSources'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return PartnerShareRecord(
      familyUid: doc.id,
      score: (data['score'] as num?)?.round() ?? 0,
      dayKey: (data['dayKey'] as String?) ?? '',
      topStressSources: stress,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Partner view of de-identified family wellness trends.
class PartnerHomePage extends StatelessWidget {
  const PartnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner insights'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => AuthSession.confirmAndSignOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('partner_shares')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No families are sharing de-identified wellness trends yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final shares =
              docs.map(PartnerShareRecord.fromDoc).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Text(
                'Shared wellness trends',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Families who turned on Share with Partners appear here without names.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ...shares.map((share) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _scoreColor(share.score).withValues(alpha: 0.15),
                      child: Text(
                        '${share.score}',
                        style: TextStyle(
                          color: _scoreColor(share.score),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text('Family ${share.familyUid.substring(0, 6)}…'),
                    subtitle: Text(
                      [
                        if (share.dayKey.isNotEmpty) 'Latest check-in: ${share.dayKey}',
                        if (share.topStressSources.isNotEmpty)
                          'Stress: ${share.topStressSources.join(', ')}',
                      ].join('\n'),
                    ),
                    isThreeLine: share.topStressSources.isNotEmpty,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  static Color _scoreColor(int score) {
    if (score >= 70) return const Color(0xFF439A7D);
    if (score >= 55) return const Color(0xFFF9A825);
    return const Color(0xFFD32F2F);
  }
}
