import 'family_insights_copy.dart';
import 'support_catalog.dart';

/// Volunteer service suggestion derived from check-in patterns.
class VolunteerServiceRecommendation {
  const VolunteerServiceRecommendation({
    required this.serviceType,
    required this.title,
    required this.subtitle,
    required this.reason,
  });

  final String serviceType;
  final String title;
  final String subtitle;
  final String reason;
}

/// Data-driven picks for events, resources, groups, and volunteer help.
class PersonalizedSupportPlan {
  const PersonalizedSupportPlan({
    required this.headline,
    required this.resources,
    required this.resourceReasons,
    required this.peerGroups,
    required this.peerGroupReasons,
    required this.volunteerServices,
    this.featuredEvent,
    this.eventReason,
    this.highlightCrisisLine = false,
    this.hasCheckInData = false,
  });

  final String headline;
  final List<CatalogResource> resources;
  final Map<String, String> resourceReasons;
  final List<CatalogPeerGroup> peerGroups;
  final Map<String, String> peerGroupReasons;
  final List<VolunteerServiceRecommendation> volunteerServices;
  final CatalogSupportEvent? featuredEvent;
  final String? eventReason;
  final bool highlightCrisisLine;
  final bool hasCheckInData;

  factory PersonalizedSupportPlan.empty() {
    return PersonalizedSupportPlan(
      headline: 'Complete a check-in to see support matched to your trends',
      resources: SupportRecommendations.defaultResources(),
      resourceReasons: const {},
      peerGroups: SupportCatalog.peerGroups.take(1).toList(),
      peerGroupReasons: const {},
      volunteerServices: const [
        VolunteerServiceRecommendation(
          serviceType: 'respite',
          title: 'Respite care',
          subtitle: 'Take a break while someone helps',
          reason: 'Available once we learn your wellness patterns',
        ),
      ],
      featuredEvent: SupportCatalog.nextEvent,
      eventReason: 'Open to all families',
      hasCheckInData: false,
    );
  }
}

class SupportRecommendations {
  SupportRecommendations._();

  static List<CatalogResource> defaultResources() {
    return SupportCatalog.resourceSections.first.items.take(2).toList();
  }

  static PersonalizedSupportPlan fromInsights(
    FamilyInsightsCopy insights, {
    bool shareWithPartners = true,
  }) {
    if (!insights.hasCheckInData) {
      return PersonalizedSupportPlan.empty();
    }

    final stress = insights.stressSourceCounts;
    final topStress = _topStressKeys(stress);
    final lowestScore = _lowestScore(insights.memberScores);
    final activeCount =
        insights.memberScores.values.where((s) => s != null).length;
    final needsRest = lowestScore != null && lowestScore < 60;
    final needsUrgentSupport = lowestScore != null && lowestScore < 40;

    final resources = <CatalogResource>[];
    final resourceReasons = <String, String>{};
    final peerGroups = <CatalogPeerGroup>[];
    final peerGroupReasons = <String, String>{};
    final volunteerServices = <VolunteerServiceRecommendation>[];

    void addResource(CatalogResource resource, String reason) {
      if (resources.any((r) => r.title == resource.title)) return;
      resources.add(resource);
      resourceReasons[resource.title] = reason;
    }

    void addPeerGroup(CatalogPeerGroup group, String reason) {
      if (!shareWithPartners) return;
      if (peerGroups.any((g) => g.id == group.id)) return;
      peerGroups.add(group);
      peerGroupReasons[group.id] = reason;
    }

    final allResources = [
      for (final section in SupportCatalog.resourceSections) ...section.items,
    ];

    CatalogResource findResource(String titlePart) {
      return allResources.firstWhere(
        (r) => r.title.toLowerCase().contains(titlePart.toLowerCase()),
        orElse: () => allResources.first,
      );
    }

    CatalogPeerGroup findGroup(String id) {
      return SupportCatalog.peerGroups.firstWhere((g) => g.id == id);
    }

    if (topStress.contains('Sleep')) {
      addResource(
        findResource('Sleep routines'),
        'Sleep shows up often in your check-ins',
      );
      addPeerGroup(
        findGroup('stress-sleep'),
        'Matches your sleep-related stress pattern',
      );
    }

    if (topStress.contains('Work')) {
      addResource(
        findResource('burnout'),
        'Work is a top stress source for your family',
      );
      addResource(
        findResource('grounding'),
        'Quick regulation tools for busy days',
      );
    }

    if (topStress.contains('Medical')) {
      addResource(
        findResource('respite overview'),
        'Medical stress — respite can help caregivers recharge',
      );
      volunteerServices.add(
        const VolunteerServiceRecommendation(
          serviceType: 'transport',
          title: 'Transportation',
          subtitle: 'Rides to appointments',
          reason: 'Medical appointments are a stress source in your check-ins',
        ),
      );
    }

    if (topStress.contains('Time') || topStress.contains('Family')) {
      addResource(
        findResource('Getting started'),
        'Time and family demands are showing up in your trends',
      );
      addPeerGroup(
        findGroup('caregiver-coffee'),
        'Connect with other caregivers facing similar load',
      );
    }

    if (topStress.contains('Financial')) {
      addResource(
        findResource('Getting started'),
        'Financial stress noted — practical caregiver guides may help',
      );
    }

    if (needsRest) {
      addResource(
        findResource('burnout'),
        insights.restNeededSubtitle(),
      );
      volunteerServices.add(
        VolunteerServiceRecommendation(
          serviceType: 'respite',
          title: 'Respite care',
          subtitle: 'Take a break while we help',
          reason: lowestScore < 60
              ? 'Recent wellness scores suggest you could use a break'
              : 'Based on your family\'s recent check-ins',
        ),
      );
    }

    if (topStress.contains('Work') && topStress.contains('Time')) {
      volunteerServices.add(
        const VolunteerServiceRecommendation(
          serviceType: 'meal',
          title: 'Meal delivery',
          subtitle: 'Home-cooked meals',
          reason: 'Work and time pressure — let volunteers help with meals',
        ),
      );
    }

    if (volunteerServices.isEmpty && needsRest) {
      volunteerServices.add(
        const VolunteerServiceRecommendation(
          serviceType: 'respite',
          title: 'Respite care',
          subtitle: 'Take a break while we help',
          reason: 'Suggested from your recent wellness trends',
        ),
      );
    }

    if (activeCount <= 1 || insights.participationTitle() == 'Getting started') {
      addPeerGroup(
        findGroup('caregiver-coffee'),
        'Build momentum with other families',
      );
    }

    if (peerGroups.isEmpty) {
      addPeerGroup(
        findGroup('stress-sleep'),
        insights.planBufferSubtitle(),
      );
    }

    if (resources.isEmpty) {
      addResource(
        findResource('grounding'),
        insights.planBufferSubtitle(),
      );
      addResource(
        findResource('burnout'),
        insights.restNeededSubtitle(),
      );
    }

    final event = SupportCatalog.nextEvent;
    String? eventReason;
    if (event != null) {
      if (activeCount <= 2) {
        eventReason =
            'Your family is building check-in habits — this workshop fits where you are now';
      } else if (needsRest) {
        eventReason =
            'Wellness has dipped lately — the workshop covers family recovery strategies';
      } else {
        eventReason =
            'Recommended based on your family\'s recent check-in patterns';
      }
    }

    final headline = needsUrgentSupport
        ? 'Extra support recommended — review rest options and crisis lines'
        : needsRest
            ? insights.restNeededSubtitle()
            : topStress.isNotEmpty
                ? '${insights.planBufferSubtitle()} — see matched resources below'
                : insights.greatJobSubtitle();

    return PersonalizedSupportPlan(
      headline: headline,
      resources: resources.take(3).toList(),
      resourceReasons: resourceReasons,
      peerGroups: peerGroups.take(2).toList(),
      peerGroupReasons: peerGroupReasons,
      volunteerServices: volunteerServices.take(2).toList(),
      featuredEvent: event,
      eventReason: eventReason,
      highlightCrisisLine: needsUrgentSupport,
      hasCheckInData: true,
    );
  }

  static List<String> _topStressKeys(Map<String, int> counts) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((e) => e.key).toList();
  }

  static int? _lowestScore(Map<String, int?> scores) {
    final values = scores.values.whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a < b ? a : b);
  }
}
