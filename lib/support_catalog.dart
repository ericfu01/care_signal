/// Curated support content (events, groups, resources, volunteers).
class CatalogVolunteer {
  const CatalogVolunteer({
    required this.id,
    required this.name,
    required this.role,
    required this.specialties,
  });

  final String id;
  final String name;
  final String role;
  final List<String> specialties;
}

class CatalogPeerGroup {
  const CatalogPeerGroup({
    required this.id,
    required this.title,
    required this.schedule,
    required this.mode,
    required this.members,
  });

  final String id;
  final String title;
  final String schedule;
  final String mode;
  final String members;
}

class CatalogResource {
  const CatalogResource({
    required this.title,
    required this.minutes,
    required this.url,
  });

  final String title;
  final String minutes;
  final Uri url;
}

class CatalogResourceSection {
  const CatalogResourceSection({
    required this.heading,
    required this.items,
  });

  final String heading;
  final List<CatalogResource> items;
}

class CatalogSupportEvent {
  const CatalogSupportEvent({
    required this.id,
    required this.startsAt,
    required this.title,
    required this.isOnline,
    required this.timeDisplay,
    required this.baseFamiliesSignedUp,
  });

  final String id;
  final DateTime startsAt;
  final String title;
  final bool isOnline;
  final String timeDisplay;
  final int baseFamiliesSignedUp;

  String get monthAbbrev {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[startsAt.month - 1];
  }

  String get day => '${startsAt.day}';
}

class SupportCatalog {
  SupportCatalog._();

  static const volunteers = [
    CatalogVolunteer(
      id: 'maria-santos',
      name: 'Respite care',
      role: 'Trained respite volunteer',
      specialties: ['Respite care', 'In-home support'],
    ),
    CatalogVolunteer(
      id: 'james-chen',
      name: 'Peer support',
      role: 'Peer support volunteer',
      specialties: ['Peer support', 'Caregiver check-ins'],
    ),
    CatalogVolunteer(
      id: 'aisha-patel',
      name: 'Meal delivery',
      role: 'Meal & home support volunteer',
      specialties: ['Meal delivery', 'Light housekeeping'],
    ),
    CatalogVolunteer(
      id: 'derek-morrison',
      name: 'Transportation',
      role: 'Transportation volunteer',
      specialties: ['Medical rides', 'School pickup'],
    ),
  ];

  static CatalogVolunteer? volunteerById(String id) {
    for (final volunteer in volunteers) {
      if (volunteer.id == id) return volunteer;
    }
    return null;
  }

  static CatalogVolunteer? laneById(String id) => volunteerById(id);

  static CatalogVolunteer get transportationLane =>
      volunteers.firstWhere((v) => v.id == 'derek-morrison');

  static List<CatalogPeerGroup> get peerGroups => const [];

  static List<CatalogResourceSection> get resourceSections => [
        CatalogResourceSection(
          heading: 'Caregiving basics',
          items: [
            CatalogResource(
              title: 'Getting started as a family caregiver',
              minutes: '6 min read',
              url: Uri.parse(
                'https://www.caregiver.org/resource/getting-started/',
              ),
            ),
            CatalogResource(
              title: 'Talking with schools about accommodations',
              minutes: '8 min read',
              url: Uri.parse(
                'https://www.understood.org/en/articles/how-to-talk-to-teachers-about-your-childs-needs',
              ),
            ),
            CatalogResource(
              title: 'When you need a break: respite overview',
              minutes: '5 min read',
              url: Uri.parse(
                'https://www.archrespite.org/respitelocator',
              ),
            ),
          ],
        ),
        CatalogResourceSection(
          heading: 'Stress & regulation',
          items: [
            CatalogResource(
              title: 'Five-minute grounding exercises',
              minutes: 'Guide',
              url: Uri.parse(
                'https://www.nami.org/Your-Journey/Individuals-with-Mental-Illness/Taking-Care-of-Your-Body/Managing-Stress',
              ),
            ),
            CatalogResource(
              title: 'Sleep routines for the whole household',
              minutes: '7 min read',
              url: Uri.parse(
                'https://www.sleepfoundation.org/sleep-hygiene',
              ),
            ),
            CatalogResource(
              title: 'Recognizing burnout in yourself',
              minutes: '6 min read',
              url: Uri.parse(
                'https://www.caregiver.org/resource/caregiver-stress-and-burnout/',
              ),
            ),
          ],
        ),
        CatalogResourceSection(
          heading: 'Tools & crisis',
          items: [
            CatalogResource(
              title: '988 Suicide & Crisis Lifeline',
              minutes: 'Call or text 988',
              url: Uri.parse('https://988lifeline.org/'),
            ),
            CatalogResource(
              title: 'Crisis Text Line — text HOME to 741741',
              minutes: '24/7 text support',
              url: Uri.parse('https://www.crisistextline.org/'),
            ),
            CatalogResource(
              title: 'Find local NAMI support',
              minutes: 'Programs near you',
              url: Uri.parse('https://www.nami.org/Support-Education/Support-Groups'),
            ),
          ],
        ),
      ];

  /// Catalog demo events removed — use staff-published `community_events` only.
  static CatalogSupportEvent? get nextEvent => null;
}
