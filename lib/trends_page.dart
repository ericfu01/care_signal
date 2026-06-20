import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_check_in_loader.dart';
import 'family_models.dart';
import 'insights_ai_service.dart';
import 'openai_config.dart';
import 'support_repository.dart';
import 'wellness_trend_chart.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({
    required this.memberScores,
    required this.stressSourceCounts,
    this.currentUserName,
    this.familyProfiles = const [],
    this.familyWellnessAverage,
    super.key,
  });

  final Map<String, int?> memberScores;
  final Map<String, int> stressSourceCounts;
  final String? currentUserName;
  final List<UserProfile> familyProfiles;
  final int? familyWellnessAverage;

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  int _trendsRangeIndex = 0;
  String? _aiAlert;
  bool _aiAlertLoading = false;
  List<DailyWellnessPoint> _dailyPoints = [];
  Map<String, DateTime?> _memberLastCheckInDays = {};
  Map<String, bool> _shareTrendsByUid = {};
  bool _historyLoading = false;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  bool _canViewMemberTrends(String memberUid) {
    return SupportRepository.canViewMemberTrends(
      memberUid: memberUid,
      viewerUid: _currentUid,
      shareTrendsByUid: _shareTrendsByUid,
    );
  }

  Map<String, int?> get _visibleMemberScores {
    final uidByName = {
      for (final profile in widget.familyProfiles) profile.displayName: profile.uid,
    };
    final visible = <String, int?>{};
    for (final entry in widget.memberScores.entries) {
      final uid = uidByName[entry.key];
      if (uid == null || _canViewMemberTrends(uid)) {
        visible[entry.key] = entry.value;
      } else {
        visible[entry.key] = null;
      }
    }
    return visible;
  }

  int get _dayCount => _trendsRangeIndex == 0 ? 7 : 30;

  List<DailyWellnessPoint> get _visiblePoints {
    if (_dailyPoints.length <= _dayCount) return _dailyPoints;
    return _dailyPoints.sublist(_dailyPoints.length - _dayCount);
  }

  @override
  void initState() {
    super.initState();
    _loadAiAlert();
    _loadHistory();
  }

  @override
  void didUpdateWidget(TrendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberScores != widget.memberScores ||
        oldWidget.stressSourceCounts != widget.stressSourceCounts) {
      _loadAiAlert();
      _loadHistory();
    } else if (oldWidget.familyProfiles != widget.familyProfiles) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final uids = <String>{
      for (final profile in widget.familyProfiles) profile.uid,
    };
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (uids.isEmpty && currentUid != null && currentUid.isNotEmpty) {
      uids.add(currentUid);
    }
    if (uids.isEmpty) {
      if (!mounted) return;
      setState(() {
        _dailyPoints = [];
        _memberLastCheckInDays = {};
        _historyLoading = false;
      });
      return;
    }

    setState(() => _historyLoading = true);
    final shareTrendsByUid =
        await SupportRepository.instance.getShareTrendsEnabledByUids(
      widget.familyProfiles.map((profile) => profile.uid),
    );
    final visibleUids = widget.familyProfiles
        .where((profile) => _canViewMemberTrendsFor(
              profile.uid,
              shareTrendsByUid: shareTrendsByUid,
            ))
        .map((profile) => profile.uid)
        .toList();
    if (visibleUids.isEmpty && currentUid != null && currentUid.isNotEmpty) {
      visibleUids.add(currentUid);
    }
    final points = await FamilyCheckInLoader.dailyFamilyAveragesForUids(
      visibleUids,
      dayCount: 30,
    );
    Map<String, DateTime?> lastDays = {};
    if (widget.familyProfiles.isNotEmpty) {
      final visibleProfiles = widget.familyProfiles
          .where(
            (profile) => _canViewMemberTrendsFor(
              profile.uid,
              shareTrendsByUid: shareTrendsByUid,
            ),
          )
          .toList();
      lastDays = await FamilyCheckInLoader.latestCheckInDayByMemberName(
        visibleProfiles,
      );
    } else if (currentUid != null && widget.currentUserName != null) {
      lastDays[widget.currentUserName!] =
          await FamilyCheckInLoader.latestCheckInDayForUid(currentUid);
    }
    if (!mounted) return;
    setState(() {
      _dailyPoints = points;
      _memberLastCheckInDays = lastDays;
      _shareTrendsByUid = shareTrendsByUid;
      _historyLoading = false;
    });
  }

  bool _canViewMemberTrendsFor(
    String memberUid, {
    required Map<String, bool> shareTrendsByUid,
  }) {
    return SupportRepository.canViewMemberTrends(
      memberUid: memberUid,
      viewerUid: _currentUid,
      shareTrendsByUid: shareTrendsByUid,
    );
  }

  Future<void> _loadAiAlert() async {
    await _loadAiAlertWithScores(_visibleMemberScores);
  }

  Future<void> _loadAiAlertWithScores(Map<String, int?> memberScores) async {
    if (!memberScores.values.any((s) => s != null)) {
      if (!mounted) return;
      setState(() {
        _aiAlert = null;
        _aiAlertLoading = false;
      });
      return;
    }

    setState(() => _aiAlertLoading = true);

    final context = await InsightsAiService.instance.buildContext(
      currentUserName: widget.currentUserName ?? 'You',
      memberScores: memberScores,
      stressSourceCounts: widget.stressSourceCounts,
      familyProfiles: widget.familyProfiles,
      familyWellnessAverage: widget.familyWellnessAverage,
    );

    final result = await InsightsAiService.instance.load(context: context);

    if (!mounted) return;
    setState(() {
      _aiAlert = result.trendsAlert;
      _aiAlertLoading = false;
    });
  }

  String _buildAiAlertText() {
    final memberScores = _visibleMemberScores;
    if (_aiAlertLoading) {
      return 'AI Alert: Generating insight…';
    }
    if (_aiAlert != null && _aiAlert!.trim().isNotEmpty) {
      return _aiAlert!.trim();
    }
    if (isOpenAiConfigured &&
        memberScores.values.any((s) => s != null)) {
      return 'AI Alert: Could not load insight. Pull to refresh on Insights.';
    }
    return _ruleBasedAiAlertText(memberScores);
  }

  String _ruleBasedAiAlertText(Map<String, int?> memberScores) {
    final entries = memberScores.entries
        .where((entry) => entry.value != null)
        .map((entry) => MapEntry(entry.key, entry.value!))
        .toList();

    if (entries.isEmpty) {
      return 'AI Alert: Complete daily check-ins to generate insights.';
    }

    entries.sort((a, b) => a.value.compareTo(b.value));
    final lowest = entries.first;
    final highest = entries.last;

    if (lowest.value < 55) {
      return 'AI Alert: ${lowest.key} may need extra support today.';
    }

    if (highest.value >= 85) {
      return 'AI Alert: ${highest.key} is trending positively this week.';
    }

    return 'AI Alert: Family wellness is stable based on recent check-ins.';
  }

  Widget _buildTrendSegment(String label, int index) {
    final isSelected = _trendsRangeIndex == index;
    return GestureDetector(
      onTap: () {
        if (_trendsRangeIndex == index) return;
        setState(() {
          _trendsRangeIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.black87 : Colors.black45,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberWellnessRow({
    required String name,
    required int? score,
    required DateTime? lastCheckInDay,
    required Color barColor,
    required bool trendsShared,
  }) {
    final resolvedScore = trendsShared ? (score ?? 0) : 0;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade300,
          child: Text(
            name.substring(0, 1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    !trendsShared
                        ? '--'
                        : score != null
                            ? '$score'
                            : '--',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: !trendsShared
                          ? Colors.black38
                          : barColor == const Color(0xFFF4B321)
                              ? const Color(0xFFCC8A00)
                              : const Color(0xFF0E9F7B),
                    ),
                  ),
                ],
              ),
              Text(
                !trendsShared
                    ? 'Trends not shared'
                    : score != null
                        ? FamilyCheckInLoader.formatLastCheckInLabel(
                            lastCheckInDay,
                          )
                        : 'No check-ins yet',
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: trendsShared && score != null
                      ? resolvedScore / 100
                      : 0.0,
                  backgroundColor: const Color(0xFFEFF1F4),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleScores = _visibleMemberScores;
    final memberWellness = widget.familyProfiles.isNotEmpty
        ? [
            for (final profile in (widget.familyProfiles.toList()
              ..sort((a, b) => a.displayName.compareTo(b.displayName))))
              (
                profile.displayName == widget.currentUserName
                    ? '${profile.displayName} (You)'
                    : profile.displayName,
                visibleScores[profile.displayName],
                _memberLastCheckInDays[profile.displayName],
                _canViewMemberTrends(profile.uid),
                (visibleScores[profile.displayName] ?? 0) >= 70
                    ? const Color(0xFF31C6B3)
                    : const Color(0xFFF4B321),
              ),
          ]
        : [
            for (final name in (visibleScores.keys.toList()..sort()))
              (
                name == widget.currentUserName ? '$name (You)' : name,
                visibleScores[name],
                _memberLastCheckInDays[name],
                true,
                (visibleScores[name] ?? 0) >= 70
                    ? const Color(0xFF31C6B3)
                    : const Color(0xFFF4B321),
              ),
          ];
    final chartScores = _visiblePoints
        .map((p) => p.averageScore?.round())
        .whereType<int>()
        .toList();
    final averageScore = chartScores.isEmpty
        ? null
        : (chartScores.reduce((a, b) => a + b) / chartScores.length).round();
    final checkInDaysInRange = chartScores.length;
    final sortedStressSources = widget.stressSourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalStressReports = widget.stressSourceCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Trends',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _buildTrendSegment('Week', 0),
                    _buildTrendSegment('Month', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEAECEF)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Wellness Index',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F9F3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        averageScore != null ? '$averageScore' : '--',
                        style: TextStyle(
                          color: averageScore != null
                              ? const Color(0xFF0E9F7B)
                              : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    minHeight: 14,
                    value: averageScore != null
                        ? averageScore.clamp(0, 100) / 100.0
                        : 0.0,
                    backgroundColor: const Color(0xFFEFF1F4),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0E9F7B),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  averageScore != null
                      ? '$averageScore% average across '
                          '$checkInDaysInRange check-in '
                          '${checkInDaysInRange == 1 ? 'day' : 'days'} '
                          'in the last $_dayCount days'
                      : 'No check-ins in the last $_dayCount days.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 20),
                if (_historyLoading)
                  const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  WellnessTrendChart(points: _visiblePoints),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEAECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member Wellness',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ...memberWellness.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMemberWellnessRow(
                      name: item.$1,
                      score: item.$2,
                      lastCheckInDay: item.$3,
                      trendsShared: item.$4,
                      barColor: item.$5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF0E0AB)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE8A6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tips_and_updates, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _buildAiAlertText(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEAECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stress Sources',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (totalStressReports == 0)
                  Text(
                    'No stress source responses yet.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black54,
                        ),
                  )
                else
                  ...sortedStressSources.take(5).map((entry) {
                    final percent =
                        ((entry.value / totalStressReports) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
