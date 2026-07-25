import 'package:flutter/material.dart';

import 'partner_home_page.dart';
import 'partner_share_repository.dart';
import 'wellness_trend_chart.dart';

/// De-identified trend history for one family share.
class PartnerFamilyDetailPage extends StatelessWidget {
  const PartnerFamilyDetailPage({
    required this.share,
    super.key,
  });

  final PartnerShareRecord share;

  String get _label {
    final id = share.familyUid;
    if (id.length <= 6) return 'Family $id';
    return 'Family ${id.substring(0, 6)}…';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_label),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    PartnerHomePage.scoreColor(share.score).withValues(alpha: 0.15),
                child: Text(
                  '${share.score}',
                  style: TextStyle(
                    color: PartnerHomePage.scoreColor(share.score),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: const Text('Latest shared score'),
              subtitle: Text(
                [
                  if (share.dayKey.isNotEmpty) 'Day: ${share.dayKey}',
                  if (share.topStressSources.isNotEmpty)
                    'Stress: ${share.topStressSources.join(', ')}',
                ].join('\n'),
              ),
              isThreeLine: share.topStressSources.isNotEmpty,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Wellness trend',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'De-identified daily scores shared by this family (no names).',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<PartnerHistoryPoint>>(
            stream: PartnerShareRepository.instance.watchHistory(share.familyUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final history = snapshot.data ?? [];
              final points =
                  history.map((p) => p.toDailyWellnessPoint()).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                      child: WellnessTrendChart(points: points, height: 180),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Recent days',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    Text(
                      'No history yet. It fills in as this family completes check-ins '
                      'with Share with Partners on.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    )
                  else
                    ...history.reversed.map((point) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: PartnerHomePage.scoreColor(point.score)
                              .withValues(alpha: 0.15),
                          child: Text(
                            '${point.score}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: PartnerHomePage.scoreColor(point.score),
                            ),
                          ),
                        ),
                        title: Text(point.dayKey),
                        subtitle: point.topStressSources.isEmpty
                            ? null
                            : Text(point.topStressSources.join(', ')),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
