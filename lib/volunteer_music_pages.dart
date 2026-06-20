import 'package:flutter/material.dart';

import 'music_therapy_search_section.dart';
import 'family_models.dart';
import 'spotify_launcher.dart';
import 'spotify_links.dart';
import 'support_catalog.dart';
import 'support_repository.dart';
import 'family_volunteer_request_helpers.dart';
import 'family_volunteer_requests_page.dart';
import 'request_duration.dart';
import 'volunteer_matching.dart';
import 'volunteer_message_schedule_pages.dart';
import 'volunteer_profile_stats.dart';

const _volunteerAccentColors = [
  Color(0xFF439A7D),
  Color(0xFF5C6BC0),
  Color(0xFF00897B),
  Color(0xFF7B1FA2),
];

Color _volunteerAccentColor(CatalogVolunteer volunteer) {
  final index =
      SupportCatalog.volunteers.indexWhere((v) => v.id == volunteer.id);
  return _volunteerAccentColors[
      index >= 0 ? index % _volunteerAccentColors.length : 0];
}

void _openVolunteerMessage(BuildContext context, VolunteerCardModel model) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => VolunteerMessagePage(
        volunteerId: model.catalogId,
        volunteerName: model.displayName,
      ),
    ),
  );
}

Future<void> _openVolunteerSchedule(
  BuildContext context,
  VolunteerCardModel model, {
  VoidCallback? onScheduled,
}) {
  return Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (context) => VolunteerSchedulePage(
            volunteerId: model.catalogId,
            volunteerName: model.displayName,
            volunteerUid: model.profile?.uid,
          ),
        ),
      )
      .then((_) => onScheduled?.call());
}

Future<void> _openTransportationRequest(
  BuildContext context, {
  VoidCallback? onSubmitted,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => TransportationRequestPage(
        onSubmitted: onSubmitted,
      ),
    ),
  );
}

class VolunteerPage extends StatefulWidget {
  const VolunteerPage({super.key});

  @override
  State<VolunteerPage> createState() => _VolunteerPageState();
}

class _VolunteerPageState extends State<VolunteerPage> {
  VolunteerImpactSummary _impact =
      const VolunteerImpactSummary(hours: 0, meals: 0, rides: 0);

  @override
  void initState() {
    super.initState();
    _loadImpact();
  }

  Future<void> _loadImpact() async {
    final impact = await SupportRepository.instance.loadVolunteerImpact();
    if (!mounted) return;
    setState(() => _impact = impact);
  }

  Future<void> _requestService(String type, String label) async {
    final catalogId = VolunteerMatching.catalogIdForServiceType(type);
    final form = await showSupportRequestFormDialog(
      context,
      title: 'Request $label',
      defaultDurationMinutes: RequestDuration.defaultForService(type),
      validate: catalogId == null
          ? null
          : (data) {
              if (data.urgent) return Future.value(null);
              final start = data.needsNow ? DateTime.now() : data.scheduledAt!;
              return VolunteerMatching.instance.scheduleConflictMessage(
                catalogId: catalogId,
                start: start,
                durationMinutes: data.durationMinutes,
              );
            },
    );
    if (form == null) return;

    try {
      await SupportRepository.instance.submitServiceRequest(
        serviceType: type,
        label: label,
        durationMinutes: form.durationMinutes,
        needsNow: form.needsNow,
        urgent: form.urgent,
        scheduledAt: form.scheduledAt,
        instructions: form.instructions.isEmpty ? null : form.instructions,
      );
      if (!mounted) return;
      await _loadImpact();
      final whenLabel = form.needsNow
          ? 'ASAP'
          : _formatScheduledTime(form.scheduledAt!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent for $label · $whenLabel.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    }
  }

  String _formatScheduledTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} · $hour:$minute $period';
  }

  String _formatVisit(Map<String, dynamic> request) =>
      FamilyVolunteerRequestHelpers.formatVisit(request);

  String _visitTitle(Map<String, dynamic> request) =>
      FamilyVolunteerRequestHelpers.visitTitle(request);

  void _openAllRequests() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FamilyVolunteerRequestsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matching = VolunteerMatching.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Volunteers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: [
          StreamBuilder<Map<String, List<UserProfile>>>(
            stream: matching.watchProfilesByLane(),
            builder: (context, snap) {
              final onlineCount =
                  matching.countAvailable(snap.data ?? const {});
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: onlineCount > 0
                                ? Colors.green.shade600
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$onlineCount online',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<Map<String, List<UserProfile>>>(
          stream: matching.watchProfilesByLane(),
          builder: (context, snap) {
            final byLane = snap.data ?? const {};
            final liveVolunteers = matching.liveVolunteerCards(byLane);
            final respiteVolunteers = matching.liveVolunteerCards(
              byLane,
              catalogId: VolunteerMatching.respiteCatalogId,
            );

            return RefreshIndicator(
              onRefresh: _loadImpact,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                respiteVolunteers.length <= 1
                                    ? 'Respite volunteer'
                                    : 'Respite volunteers',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                liveVolunteers.isEmpty
                                    ? 'No one has signed up yet — send a request and we will match you when volunteers are available.'
                                    : liveVolunteers
                                            .where((v) => v.isAvailableNow)
                                            .isNotEmpty
                                        ? 'Message or schedule with someone available now'
                                        : '${liveVolunteers.length} signed up · check back during their scheduled hours',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.black54,
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => VolunteerAllPage(
                                  initialByLane: byLane,
                                ),
                              ),
                            );
                          },
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (liveVolunteers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          'Volunteers appear here as people sign up for respite, meals, rides, and other help.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                                height: 1.4,
                              ),
                        ),
                      )
                    else
                      for (final model in liveVolunteers) ...[
                        _VolunteerProfileCard(
                          model: model,
                          cardColor: _volunteerAccentColor(model.lane),
                          featuredMatch: model.isAvailableNow,
                          onMessage: () =>
                              _openVolunteerMessage(context, model),
                          onSchedule: () => _openVolunteerSchedule(
                            context,
                            model,
                            onScheduled: _loadImpact,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                const SizedBox(height: 14),
                Text(
                  'Support Available',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 12),
                _ServiceRequestTile(
                  icon: Icons.home_rounded,
                  title: 'Respite care',
                  subtitle: 'Take a break while we help',
                  badge: '5 hrs/wk',
                  onRequest: () => _requestService('respite', 'Respite care'),
                ),
                const SizedBox(height: 12),
                _ServiceRequestTile(
                  icon: Icons.set_meal_rounded,
                  title: 'Meal delivery',
                  subtitle: 'Home-cooked meals',
                  badge: '2x/wk',
                  onRequest: () => _requestService('meal', 'Meal delivery'),
                ),
                const SizedBox(height: 12),
                _ServiceRequestTile(
                  icon: Icons.directions_car_rounded,
                  title: 'Transportation',
                  subtitle: 'Rides to appointments',
                  badge: 'On request',
                  onRequest: () => _openTransportationRequest(
                    context,
                    onSubmitted: _loadImpact,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Upcoming visit',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openAllRequests,
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupportRepository.instance.watchVolunteerRequests(),
                  builder: (context, snapshot) {
                    final requests = snapshot.data ?? [];
                    final upcoming = requests.where((r) {
                      final status = r['status'] as String? ?? 'pending';
                      return FamilyVolunteerRequestHelpers.isActive(status);
                    }).toList();
                    if (upcoming.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          'No visits scheduled yet.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                                height: 1.35,
                              ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final next in upcoming.take(3))
                          FamilyVolunteerRequestCard(
                            request: next,
                            title: _visitTitle(next),
                            subtitle: _formatVisit(next),
                            showActions: true,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Your support impact',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ImpactMetric(
                          value: '${_impact.hours}',
                          label: 'Hours received',
                        ),
                      ),
                      Expanded(
                        child: _ImpactMetric(
                          value: '${_impact.meals}',
                          label: 'Meals delivered',
                        ),
                      ),
                      Expanded(
                        child: _ImpactMetric(
                          value: '${_impact.rides}',
                          label: 'Rides given',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
          },
        ),
      ),
    );
  }
}

class VolunteerAllPage extends StatelessWidget {
  const VolunteerAllPage({
    super.key,
    this.initialByLane = const {},
  });

  final Map<String, List<UserProfile>> initialByLane;

  @override
  Widget build(BuildContext context) {
    final matching = VolunteerMatching.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All volunteers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<Map<String, List<UserProfile>>>(
          stream: matching.watchProfilesByLane(),
          initialData: initialByLane,
          builder: (context, snap) {
            final sections = matching.groupedLiveVolunteers(snap.data ?? const {});

            if (sections.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No volunteers have signed up yet. As people join each service lane, they will appear here with their real names.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                  ),
                ),
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                for (final section in sections) ...[
                  Text(
                    section.lane.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${section.volunteers.length} signed up',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                  const SizedBox(height: 12),
                  for (final model in section.volunteers) ...[
                    _VolunteerProfileCard(
                      model: model,
                      cardColor: _volunteerAccentColor(model.lane),
                      featuredMatch: model.isAvailableNow,
                      onMessage: () => _openVolunteerMessage(context, model),
                      onSchedule: () => _openVolunteerSchedule(context, model),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServiceRequestTile extends StatelessWidget {
  const _ServiceRequestTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onRequest,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: const Color(0xFF439A7D)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SupportRightLabel(text: badge),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImpactMetric extends StatelessWidget {
  const _ImpactMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF439A7D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportRightLabel extends StatelessWidget {
  const _SupportRightLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
        ),
      ),
    );
  }
}

/// Colored profile card with Message / Schedule actions.
class _VolunteerProfileCard extends StatelessWidget {
  const _VolunteerProfileCard({
    required this.model,
    required this.cardColor,
    required this.onMessage,
    required this.onSchedule,
    this.featuredMatch = false,
  });

  final VolunteerCardModel model;
  final Color cardColor;
  final VoidCallback onMessage;
  final VoidCallback onSchedule;
  final bool featuredMatch;

  CatalogVolunteer get volunteer => model.lane;

  VolunteerProfileStats get stats =>
      model.profile?.volunteerStats ?? const VolunteerProfileStats();

  String _initialsFromName() {
    final parts = model.displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts[0];
      return s.isEmpty ? '?' : s[0].toUpperCase();
    }
    final a = parts.first;
    final b = parts.last;
    if (a.isEmpty || b.isEmpty) return '?';
    return (a[0] + b[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      featuredMatch
                          ? Icons.star_rounded
                          : model.isAvailableNow
                              ? Icons.circle
                              : Icons.circle_outlined,
                      color: featuredMatch
                          ? Colors.white
                          : model.isAvailableNow
                              ? Colors.lightGreenAccent
                              : Colors.white70,
                      size: featuredMatch ? 16 : 10,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      featuredMatch
                          ? 'Available now'
                          : model.isAvailableNow
                              ? 'Available now'
                              : 'Offline',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 76,
                  height: 76,
                  color: Colors.black.withValues(alpha: 0.14),
                  alignment: Alignment.center,
                  child: Text(
                    _initialsFromName(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      volunteer.role,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.25,
                      ),
                    ),
                    if (model.isRegistered) ...[
                      const SizedBox(height: 4),
                      Text(
                        volunteer.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          stats.hasActivity
                              ? Icons.verified_rounded
                              : Icons.fiber_new_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            stats.summaryLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (volunteer.specialties.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final specialty in volunteer.specialties)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        specialty,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text(
                    'Message',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSchedule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.event_rounded),
                  label: const Text(
                    'Schedule',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MusicPage extends StatelessWidget {
  const MusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Music Therapy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Playlists and songs open in the Spotify app on your phone.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'AI Recommended',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Suggested for you',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _FeaturedSpotifyCard(
                link: kFeaturedEveningPlaylist,
                onOpen: () =>
                    SpotifyLauncher.open(context, kFeaturedEveningPlaylist),
              ),
              const SizedBox(height: 12),
              const MusicTherapySearchSection(
                hintText: 'e.g. evening jazz, Weightless, Spotify link…',
              ),
              const SizedBox(height: 28),
              Text(
                'For Your Mood',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 132,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ForYourMoodBox(
                        icon: Icons.bedtime_rounded,
                        iconGradientColors: [
                          Colors.indigo.shade300,
                          Colors.indigo.shade500,
                          Colors.indigo.shade700,
                        ],
                        title: 'Sleep',
                        trackCount:
                            moodSpotifyContent('Sleep').tracks.length + 1,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (context) => MoodPlaylistPage(
                                moodTitle: 'Sleep',
                                icon: Icons.bedtime_rounded,
                                iconGradientColors: [
                                  Colors.indigo.shade300,
                                  Colors.indigo.shade500,
                                  Colors.indigo.shade700,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ForYourMoodBox(
                        icon: Icons.spa_rounded,
                        iconGradientColors: [
                          Colors.cyan.shade300,
                          Colors.cyan.shade500,
                          Colors.teal.shade700,
                        ],
                        title: 'Calm',
                        trackCount: moodSpotifyContent('Calm').tracks.length + 1,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (context) => MoodPlaylistPage(
                                moodTitle: 'Calm',
                                icon: Icons.spa_rounded,
                                iconGradientColors: [
                                  Colors.cyan.shade300,
                                  Colors.cyan.shade500,
                                  Colors.teal.shade700,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 132,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ForYourMoodBox(
                        icon: Icons.bolt_rounded,
                        iconGradientColors: [
                          Colors.amber.shade300,
                          Colors.orange.shade500,
                          Colors.deepOrange.shade700,
                        ],
                        title: 'Energize',
                        trackCount:
                            moodSpotifyContent('Energize').tracks.length + 1,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (context) => MoodPlaylistPage(
                                moodTitle: 'Energize',
                                icon: Icons.bolt_rounded,
                                iconGradientColors: [
                                  Colors.amber.shade300,
                                  Colors.orange.shade500,
                                  Colors.deepOrange.shade700,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ForYourMoodBox(
                        icon: Icons.favorite_rounded,
                        iconGradientColors: [
                          Colors.pink.shade200,
                          Colors.pink.shade400,
                          Colors.pink.shade600,
                        ],
                        title: 'Comfort',
                        trackCount:
                            moodSpotifyContent('Comfort').tracks.length + 1,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (context) => MoodPlaylistPage(
                                moodTitle: 'Comfort',
                                icon: Icons.favorite_rounded,
                                iconGradientColors: [
                                  Colors.pink.shade200,
                                  Colors.pink.shade400,
                                  Colors.pink.shade600,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.shade600,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: 32,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalized for You',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Based on your stress patterns, calming music helps most on ____',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.black54,
                                  height: 1.45,
                                ),
                          ),
                        ],
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

/// Tappable featured playlist card (artwork, title, and open action).
class _FeaturedSpotifyCard extends StatelessWidget {
  const _FeaturedSpotifyCard({
    required this.link,
    required this.onOpen,
  });

  final SpotifyMusicLink link;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black12),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            children: [
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.teal.shade300,
                              Colors.teal.shade900,
                            ],
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.album_rounded,
                              size: 72,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                link.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                link.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: Colors.teal.shade800,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Open in Spotify',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mood list: curated Spotify playlist + tracks; each row opens in the Spotify app.
class MoodPlaylistPage extends StatelessWidget {
  const MoodPlaylistPage({
    super.key,
    required this.moodTitle,
    required this.icon,
    required this.iconGradientColors,
  }) : assert(iconGradientColors.length >= 2);

  final String moodTitle;
  final IconData icon;
  final List<Color> iconGradientColors;

  @override
  Widget build(BuildContext context) {
    final content = moodSpotifyContent(moodTitle);
    return Scaffold(
      appBar: AppBar(
        title: Text(moodTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Material(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => SpotifyLauncher.open(context, content.playlist),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.queue_music_rounded, color: Colors.teal.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.playlist.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            content.playlist.subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded, color: Colors.teal.shade800),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Opens in Spotify',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                ),
          ),
          if (content.tracks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Individual songs',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ...content.tracks.map(
              (link) => _SpotifyLinkTile(
                link: link,
                icon: icon,
                iconGradientColors: iconGradientColors,
              ),
            ),
          ],
          const SizedBox(height: 24),
          MusicTherapySearchSection(
            hintText: 'Search $moodTitle music, artist, or paste a link',
          ),
        ],
      ),
    );
  }
}

class _SpotifyLinkTile extends StatelessWidget {
  const _SpotifyLinkTile({
    required this.link,
    required this.icon,
    required this.iconGradientColors,
  });

  final SpotifyMusicLink link;
  final IconData icon;
  final List<Color> iconGradientColors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black12),
        ),
        child: InkWell(
          onTap: () => SpotifyLauncher.open(context, link),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: iconGradientColors,
                        stops: iconGradientColors.length == 3
                            ? const [0.0, 0.48, 1.0]
                            : null,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        link.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.teal.shade700,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForYourMoodBox extends StatelessWidget {
  const _ForYourMoodBox({
    required this.icon,
    required this.iconGradientColors,
    required this.title,
    required this.trackCount,
    required this.onTap,
  }) : assert(iconGradientColors.length >= 2);

  final IconData icon;
  final List<Color> iconGradientColors;
  final String title;
  final int trackCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: iconGradientColors,
                    stops: iconGradientColors.length == 3
                        ? const [0.0, 0.48, 1.0]
                        : null,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: iconGradientColors.last,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '$trackCount tracks',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
