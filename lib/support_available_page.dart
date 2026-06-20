import 'package:flutter/material.dart';

import 'family_insights_copy.dart';
import 'support_action_pages.dart';
import 'support_personalized_section.dart';
import 'support_recommendations.dart';
import 'support_repository.dart';
import 'volunteer_music_pages.dart';

class SupportAvailablePage extends StatefulWidget {
  const SupportAvailablePage({super.key});

  @override
  State<SupportAvailablePage> createState() => _SupportAvailablePageState();
}

class _SupportAvailablePageState extends State<SupportAvailablePage> {
  FamilyInsightsCopy? _insights;
  PersonalizedSupportPlan _plan = PersonalizedSupportPlan.empty();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final plan =
          await SupportRepository.instance.loadPersonalizedSupportPlan();
      final copy = await SupportRepository.instance.loadInsightsCopy();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _insights = copy;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _insights = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insights = _insights;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalized support'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Personalizing suggestions for you…',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Matching resources, groups, and volunteer help to your check-ins',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _plan.headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SupportPersonalizedSection(
                    plan: _plan,
                    onOpenPeerGroups: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const PeerGroupsPage(),
                        ),
                      );
                    },
                    onOpenVolunteers: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const VolunteerPage(),
                        ),
                      );
                    },
                  ),
                  if (_plan.featuredEvent != null &&
                      _plan.eventReason != null) ...[
                    const SizedBox(height: 4),
                    _SuggestionCard(
                      icon: Icons.event_rounded,
                      title: _plan.featuredEvent!.title,
                      body: _plan.eventReason!,
                      accent: const Color(0xFF26A69A),
                    ),
                  ],
                  if (insights != null && insights.hasCheckInData) ...[
                    const SizedBox(height: 28),
                    Text(
                      'From your check-ins',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SuggestionCard(
                      icon: Icons.nightlight_round,
                      title: 'Rest & recovery',
                      body: insights.restNeededSubtitle(),
                      accent: const Color(0xFF5C6BC0),
                    ),
                    const SizedBox(height: 12),
                    _SuggestionCard(
                      icon: Icons.schedule_rounded,
                      title: 'Plan a buffer',
                      body: insights.planBufferSubtitle(),
                      accent: const Color(0xFF00897B),
                    ),
                    const SizedBox(height: 12),
                    _SuggestionCard(
                      icon: Icons.groups_rounded,
                      title: insights.participationTitle(),
                      body: insights.participationBody(),
                      accent: const Color(0xFF7B1FA2),
                    ),
                  ] else if (!_plan.hasCheckInData) ...[
                    const SizedBox(height: 20),
                    _SuggestionCard(
                      icon: Icons.edit_calendar_rounded,
                      title: 'Start with a check-in',
                      body:
                          'Complete a daily check-in so we can match resources, '
                          'peer groups, and volunteer help to your stress patterns.',
                      accent: const Color(0xFF1976D2),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Care Signal does not provide emergency services. '
                    'Use Crisis Line in Support for 24/7 help.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                        color: Colors.black87,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
