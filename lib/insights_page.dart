import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'family_insights_copy.dart';
import 'family_models.dart';
import 'insights_ai_service.dart';
import 'openai_config.dart';

/// AI Insights tab — weekly summary, tips, and family dynamics.
class InsightsPage extends StatefulWidget {
  const InsightsPage({
    super.key,
    this.familyWellnessAverage,
    this.currentUserName,
    this.familyMemberNames = const [],
    this.memberScores = const {},
    this.stressSourceCounts = const {},
    this.familyProfiles = const [],
  });

  /// Average wellness from daily check-ins (0–100), same as Home family card.
  final int? familyWellnessAverage;
  final String? currentUserName;
  final List<String> familyMemberNames;
  final Map<String, int?> memberScores;
  final Map<String, int> stressSourceCounts;
  final List<UserProfile> familyProfiles;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  InsightsAiResult? _aiResult;
  bool _aiLoading = false;
  String? _aiFingerprint;

  static const Color _navy = Color(0xFF1B2838);
  static const Color _teal = Color(0xFF26A69A);

  FamilyInsightsCopy get _copy => FamilyInsightsCopy(
        currentUserName: widget.currentUserName?.trim().isNotEmpty == true
            ? widget.currentUserName!.trim()
            : 'You',
        memberNames: widget.familyMemberNames,
        memberScores: widget.memberScores,
        stressSourceCounts: widget.stressSourceCounts,
      );

  @override
  void initState() {
    super.initState();
    _loadAiInsights();
  }

  @override
  void didUpdateWidget(InsightsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fp = _fingerprintFromWidget();
    if (fp != _aiFingerprint) {
      _loadAiInsights();
    }
  }

  String _fingerprintFromWidget() {
    final scores = widget.memberScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '${widget.familyWellnessAverage}|${scores.map((e) => "${e.key}:${e.value}").join(",")}';
  }

  Future<void> _loadAiInsights({bool forceRefresh = false}) async {
    if (!_copy.hasCheckInData) {
      setState(() {
        _aiResult = null;
        _aiLoading = false;
        _aiFingerprint = _fingerprintFromWidget();
      });
      return;
    }

    setState(() {
      _aiLoading = true;
      _aiFingerprint = _fingerprintFromWidget();
    });

    final context = await InsightsAiService.instance.buildContext(
      currentUserName: widget.currentUserName ?? 'You',
      memberScores: widget.memberScores,
      stressSourceCounts: widget.stressSourceCounts,
      familyProfiles: widget.familyProfiles,
      familyWellnessAverage: widget.familyWellnessAverage,
    );

    final result = await InsightsAiService.instance.load(
      context: context,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;
    setState(() {
      _aiResult = result;
      _aiLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tips = _copy;
    return RefreshIndicator(
      onRefresh: () => _loadAiInsights(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                  ),
                ),
                Expanded(
                  child: Text(
                    'AI Insights',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _navy,
                        ),
                  ),
                ),
                if (_copy.hasCheckInData && isOpenAiConfigured)
                  IconButton(
                    onPressed: _aiLoading
                        ? null
                        : () => _loadAiInsights(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh AI summary',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _WeeklySummaryCard(
              wellnessAverage: widget.familyWellnessAverage,
              aiSummary: _aiResult?.summary,
              aiLoading: _aiLoading,
              aiError: _aiResult?.errorMessage,
              showAiSetupHint:
                  !isOpenAiConfigured && tips.hasCheckInData,
            ),
            const SizedBox(height: 28),
            Text(
              "Today's Tips",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
            ),
            if (!tips.hasCheckInData) ...[
              const SizedBox(height: 8),
              Text(
                'Complete a daily check-in to unlock personalized tips for your family.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            _InsightTipCard(
              icon: Icons.nightlight_round,
              iconColor: const Color(0xFF1B5E20),
              iconBoxColor: const Color(0xFFE8F5E9),
              title: 'Rest Needed',
              subtitle: tips.restNeededSubtitle(),
              onTap: () => _showTipSnack(context),
            ),
            const SizedBox(height: 12),
            _InsightTipCard(
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFF1565C0),
              iconBoxColor: const Color(0xFFE3F2FD),
              title: 'Plan Buffer Time',
              subtitle: tips.planBufferSubtitle(),
              onTap: () => _showTipSnack(context),
            ),
            const SizedBox(height: 12),
            _InsightTipCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFF6A1B9A),
              iconBoxColor: const Color(0xFFF3E5F5),
              title: tips.greatJobTitle(),
              subtitle: tips.greatJobSubtitle(),
              onTap: () => _showTipSnack(context),
            ),
            const SizedBox(height: 28),
            Text(
              'Family Dynamics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.groups_2_rounded, color: _teal, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          tips.participationTitle(),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _navy,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tips.participationBody(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Family Dynamics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final dynamicsScores =
                    _dynamicsCategoryScores(widget.familyWellnessAverage);
                return Card(
                  elevation: 1,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final tile = (w - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var i = 0; i < dynamicsScores.length; i++)
                              SizedBox(
                                width: tile,
                                height: tile,
                                child: _DynamicsScoreTile(
                                  label: dynamicsScores[i].$1,
                                  score: dynamicsScores[i].$2,
                                  accentIndex: i,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _NextWeekForecastCard(
              wellnessAverage: widget.familyWellnessAverage,
            ),
          ],
        ),
      ),
    );
  }

  void _showTipSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tips are based on your family\'s check-in data.'),
      ),
    );
  }
}

String _wellnessHeadline(int? score) {
  if (score == null) return 'Start Your Journey';
  if (score >= 85) return 'Resilience Strong';
  if (score >= 70) return 'Resilience Growing';
  if (score >= 55) return 'Building Steadily';
  return 'Every Step Counts';
}

String _wellnessPercentileBadge(int? score) {
  if (score == null) return 'Complete check-ins for your tier';
  final s = score.clamp(0, 100);
  if (s >= 92) return 'Top 10% Family Wellness';
  if (s >= 85) return 'Top 15% Family Wellness';
  if (s >= 75) return 'Top 25% Family Wellness';
  if (s >= 65) return 'Top 35% Family Wellness';
  if (s >= 55) return 'Top 50% Family Wellness';
  return 'Growing Together';
}

List<(String, int?)> _dynamicsCategoryScores(int? wellnessAverage) {
  if (wellnessAverage == null) {
    return [
      ('Communication', null),
      ('Emotional', null),
      ('Consistency', null),
      ('Load Balance', null),
    ];
  }
  final w = wellnessAverage.clamp(0, 100);
  int blend(double factor, int offset) {
    final v = (w * factor + offset).round();
    if (v < 0) return 0;
    if (v > 100) return 100;
    return v;
  }

  return [
    ('Communication', blend(0.96, 2)),
    ('Emotional', blend(0.91, 4)),
    ('Consistency', blend(0.98, 1)),
    ('Load Balance', blend(0.94, 3)),
  ];
}

const List<Color> _dynamicsAccentColors = [
  Color(0xFF6A1B9A),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFFE65100),
];

class _DynamicsScoreTile extends StatelessWidget {
  const _DynamicsScoreTile({
    required this.label,
    required this.score,
    required this.accentIndex,
  });

  final String label;
  final int? score;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    final accent =
        _dynamicsAccentColors[accentIndex % _dynamicsAccentColors.length];
    final raw = score?.clamp(0, 100) ?? 0;
    final progress = score != null ? raw / 100.0 : 0.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: Colors.grey.shade200,
                          color: accent,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        score != null ? '$raw' : '--',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: score != null
                                  ? _InsightsPageState._navy
                                  : Colors.black38,
                              height: 1,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _InsightsPageState._navy,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _nextWeekForecastTitle(int? wellnessAverage) {
  if (wellnessAverage == null) return 'Outlook';
  final w = wellnessAverage.clamp(0, 100);
  if (w >= 82) return 'Bright';
  if (w >= 68) return 'Steady';
  if (w >= 52) return 'Mixed';
  return 'Cautious';
}

Color _nextWeekDayBarColor(int dayIndex, int? wellnessAverage) {
  if (wellnessAverage == null) return Colors.grey.shade400;
  final w = wellnessAverage.clamp(0, 100);
  final tilt = (dayIndex * 17 + w * 2) % 100;
  if (tilt >= 58) return const Color(0xFF2E7D32);
  if (tilt >= 30) return const Color(0xFFF9A825);
  return const Color(0xFFC62828);
}

class _NextWeekForecastCard extends StatelessWidget {
  const _NextWeekForecastCard({required this.wellnessAverage});

  final int? wellnessAverage;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final forecastWord = _nextWeekForecastTitle(wellnessAverage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next week',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _InsightsPageState._navy,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '$forecastWord forecast',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _InsightsPageState._navy,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Showing your health for next week.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _dayLabels[i],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 6,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _nextWeekDayBarColor(i, wellnessAverage),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    this.wellnessAverage,
    this.aiSummary,
    this.aiLoading = false,
    this.aiError,
    this.showAiSetupHint = false,
  });

  final int? wellnessAverage;
  final String? aiSummary;
  final bool aiLoading;
  final String? aiError;
  final bool showAiSetupHint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7B1FA2),
              Color(0xFF3949AB),
              Color(0xFF1E88E5),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Weekly Summary',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _wellnessHeadline(wellnessAverage),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (aiLoading) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Generating AI summary…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ] else if (aiSummary != null && aiSummary!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  aiSummary!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.45,
                      ),
                ),
              ] else if (aiError != null) ...[
                const SizedBox(height: 12),
                Text(
                  aiError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                ),
              ] else if (showAiSetupHint) ...[
                const SizedBox(height: 12),
                Text(
                  kDebugMode
                      ? 'Add OPENAI_API_KEY in assets/openai.local.env for an AI-written summary.'
                      : 'AI summary is unavailable right now. Your check-in trends below still work.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.amber.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _wellnessPercentileBadge(wellnessAverage),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightTipCard extends StatelessWidget {
  const _InsightTipCard({
    required this.icon,
    required this.iconColor,
    required this.iconBoxColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBoxColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBoxColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: iconColor,
                  weight: 700,
                  grade: 50,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
