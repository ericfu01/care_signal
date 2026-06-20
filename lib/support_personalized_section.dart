import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'support_catalog.dart';
import 'support_recommendations.dart';
import 'support_repository.dart';
import 'request_duration.dart';
import 'volunteer_matching.dart';
import 'volunteer_message_schedule_pages.dart';

/// Cards showing why each resource, group, or volunteer option was picked.
class SupportPersonalizedSection extends StatelessWidget {
  const SupportPersonalizedSection({
    super.key,
    required this.plan,
    this.onOpenVolunteers,
    this.onOpenPeerGroups,
  });

  final PersonalizedSupportPlan plan;
  final VoidCallback? onOpenVolunteers;
  final VoidCallback? onOpenPeerGroups;

  Future<void> _openResource(BuildContext context, CatalogResource resource) async {
    final launched = await launchUrl(
      resource.url,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${resource.url.host}')),
      );
    }
  }

  Future<void> _requestVolunteer(
    BuildContext context,
    VolunteerServiceRecommendation service,
  ) async {
    if (service.serviceType == 'transport') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const TransportationRequestPage(),
        ),
      );
      return;
    }

    try {
      final catalogId =
          VolunteerMatching.catalogIdForServiceType(service.serviceType);
      final form = await showSupportRequestFormDialog(
        context,
        title: 'Request ${service.title}',
        defaultDurationMinutes:
            RequestDuration.defaultForService(service.serviceType),
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
      if (form == null || !context.mounted) return;

      await SupportRepository.instance.submitServiceRequest(
        serviceType: service.serviceType,
        label: service.title,
        durationMinutes: form.durationMinutes,
        needsNow: form.needsNow,
        urgent: form.urgent,
        scheduledAt: form.scheduledAt,
        instructions: form.instructions.isEmpty ? null : form.instructions,
      );
      if (!context.mounted) return;
      final whenLabel = form.needsNow
          ? 'ASAP'
          : '${form.scheduledAt!.month}/${form.scheduledAt!.day}/${form.scheduledAt!.year} '
              'at ${TimeOfDay.fromDateTime(form.scheduledAt!).format(context)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent for ${service.title} · $whenLabel.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!plan.hasCheckInData &&
        plan.resources.isEmpty &&
        plan.volunteerServices.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final items = <Widget>[];

    for (final resource in plan.resources) {
      items.add(
        _RecommendationTile(
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFFF57C00),
          title: resource.title,
          reason: plan.resourceReasons[resource.title] ?? resource.minutes,
          onTap: () => _openResource(context, resource),
        ),
      );
    }

    for (final service in plan.volunteerServices) {
      items.add(
        _RecommendationTile(
          icon: Icons.volunteer_activism_rounded,
          iconColor: const Color(0xFF439A7D),
          title: service.title,
          reason: service.reason,
          subtitle: service.subtitle,
          onTap: () => _requestVolunteer(context, service),
        ),
      );
    }

    for (final group in plan.peerGroups) {
      items.add(
        _RecommendationTile(
          icon: Icons.groups_rounded,
          iconColor: const Color(0xFF7B1FA2),
          title: group.title,
          reason: plan.peerGroupReasons[group.id] ?? group.schedule,
          subtitle: group.mode,
          onTap: onOpenPeerGroups,
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended for you',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          plan.hasCheckInData
              ? 'Based on your check-ins and stress patterns'
              : 'Complete a check-in for better matches',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black54,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (tile) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: tile,
          ),
        ),
        if (onOpenVolunteers != null) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onOpenVolunteers,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open Volunteers to message or schedule'),
          ),
        ],
      ],
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.reason,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String reason;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: iconColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black45,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}
