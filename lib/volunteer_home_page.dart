import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'family_models.dart';
import 'family_repository.dart';
import 'support_catalog.dart';
import 'volunteer_availability.dart';
import 'volunteer_availability_page.dart';
import 'counter_time_dialog.dart';
import 'volunteer_family_chat_page.dart';
import 'volunteer_profile_stats.dart';
import 'volunteer_repository.dart';
import 'volunteer_request_detail_page.dart';
import 'volunteer_setup_page.dart';
import 'notifications_page.dart';
import 'notification_repository.dart';

class VolunteerHomePage extends StatefulWidget {
  const VolunteerHomePage({super.key});

  @override
  State<VolunteerHomePage> createState() => _VolunteerHomePageState();
}

class _VolunteerHomePageState extends State<VolunteerHomePage> {
  UserProfile? _profile;
  bool _loading = true;
  int _tabIndex = 0;
  int _requestFilter = 0;
  DateTime _now = DateTime.now();
  Timer? _availabilityTimer;
  StreamSubscription<UserProfile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _profileSub = FamilyRepository.instance.watchUserProfile(uid).listen(
        (profile) {
          if (!mounted) return;
          setState(() {
            _profile = profile;
            _loading = false;
          });
        },
        onError: (Object e, StackTrace st) {
          debugPrint('[CareSignal][VolunteerHome] profile stream failed: $e');
          debugPrint('$st');
          if (mounted) setState(() => _loading = false);
        },
      );
    } else {
      _loading = false;
    }
    unawaited(_runInitialAvailabilitySync());
    _availabilityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _syncAvailabilityQuietly();
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _availabilityTimer?.cancel();
    super.dispose();
  }

  Future<void> _runInitialAvailabilitySync() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await VolunteerRepository.instance
          .syncAvailabilityBlocksFromAcceptedRequests(uid);
    } catch (e, st) {
      debugPrint(
        '[CareSignal][VolunteerHome] syncAvailabilityBlocks failed: $e',
      );
      debugPrint('$st');
    }
    try {
      await FamilyRepository.instance.syncVolunteerOnlineFromSchedule(uid);
    } catch (e, st) {
      debugPrint(
        '[CareSignal][VolunteerHome] syncVolunteerOnline failed: $e',
      );
      debugPrint('$st');
    }
    if (mounted) setState(() => _now = DateTime.now());
  }

  Future<void> _loadProfile() async {
    await _runInitialAvailabilitySync();
  }

  Future<void> _syncAvailabilityQuietly() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await VolunteerRepository.instance.syncAvailabilityBlocksFromAcceptedRequests(uid);
    await FamilyRepository.instance.syncVolunteerOnlineFromSchedule(uid);
  }

  Future<void> _openAvailabilityEditor() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VolunteerAvailabilityPage(
          initialSchedule:
              _profile?.volunteerSchedule() ?? VolunteerAvailabilitySchedule.empty,
        ),
      ),
    );
    if (saved == true) {
      await _loadProfile();
    }
  }

  bool get _availableNow => _profile?.isVolunteerAvailableNow(_now) ?? false;

  CatalogVolunteer? get _lane {
    final id = _profile?.volunteerCatalogId;
    if (id == null) return null;
    return SupportCatalog.volunteerById(id);
  }

  String get _catalogId => _profile?.volunteerCatalogId ?? '';
  String get _volunteerName => _profile?.displayName ?? 'Volunteer';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitle),
        actions: [
          StreamBuilder<int>(
            stream: NotificationRepository.instance.watchUnreadCount(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 9 ? '9+' : '$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
              );
            },
          ),
          if (_availableNow)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: const Text('Online'),
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide(color: Colors.green.shade200),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _DashboardTab(
            profile: _profile,
            lane: _lane,
            catalogId: _catalogId,
            now: _now,
            availableNow: _availableNow,
            onEditSchedule: _openAvailabilityEditor,
            onOpenRequests: () => setState(() {
              _tabIndex = 1;
              _requestFilter = 0;
            }),
          ),
          _RequestsTab(
            catalogId: _catalogId,
            filterIndex: _requestFilter,
            onFilterChanged: (i) => setState(() => _requestFilter = i),
            volunteerName: _volunteerName,
            onAssignmentUpdated: _loadProfile,
          ),
          _MessagesTab(
            catalogId: _catalogId,
            volunteerName: _volunteerName,
          ),
          _ProfileTab(
            profile: _profile,
            lane: _lane,
            now: _now,
            availableNow: _availableNow,
            onEditSchedule: _openAvailabilityEditor,
            onChangeLane: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const VolunteerSetupPage(),
                ),
              );
              await _loadProfile();
            },
            onSignOut: () => AuthSession.confirmAndSignOut(context),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String get _tabTitle {
    return switch (_tabIndex) {
      0 => 'Volunteer home',
      1 => 'Requests',
      2 => 'Messages',
      _ => 'Profile',
    };
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.profile,
    required this.lane,
    required this.catalogId,
    required this.now,
    required this.availableNow,
    required this.onEditSchedule,
    required this.onOpenRequests,
  });

  final UserProfile? profile;
  final CatalogVolunteer? lane;
  final String catalogId;
  final DateTime now;
  final bool availableNow;
  final VoidCallback onEditSchedule;
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule =
        profile?.volunteerSchedule() ?? VolunteerAvailabilitySchedule.empty;
    final activeBlock =
        profile?.availabilityBlocks.withoutExpired(now).activeBlockLabel(now);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF439A7D),
                  const Color(0xFF439A7D).withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${profile?.displayName ?? 'Volunteer'}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (lane != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    lane!.role,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      availableNow ? Icons.circle : Icons.circle_outlined,
                      color: availableNow
                          ? Colors.lightGreenAccent
                          : Colors.white70,
                      size: 12,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        schedule.statusLabel(now),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onEditSchedule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Edit weekly hours'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileSection(
            title: 'Your schedule',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (schedule.isEmpty)
                  Text(
                    'No hours set. Add your weekly availability so families can reach you during those times.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  )
                else
                  Text(
                    schedule.summaryLines(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
                  ),
                if (activeBlock != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      activeBlock,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (lane != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final specialty in lane!.specialties)
                  Chip(
                    label: Text(specialty),
                    backgroundColor: const Color(0xFF439A7D).withValues(alpha: 0.1),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (catalogId.isEmpty)
            const Text('Finish setup on the Profile tab to start receiving work.')
          else
            StreamBuilder<List<VolunteerAssignment>>(
              stream: VolunteerRepository.instance.watchAssignments(catalogId),
              builder: (context, snapshot) {
                final all = snapshot.data ?? [];
                final stats = VolunteerStats.fromAssignments(all);
                final urgent = all
                    .where((a) => a.status == 'pending' && a.needsNow)
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Needs action',
                            value: '${stats.pending}',
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Active',
                            value: '${stats.active}',
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Completed',
                            value: '${stats.completed}',
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (urgent > 0) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          leading: Icon(Icons.priority_high_rounded,
                              color: Colors.orange.shade800),
                          title: Text('$urgent ASAP request${urgent == 1 ? '' : 's'}'),
                          subtitle: const Text('Tap to review in Requests'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onOpenRequests,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Recent requests',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (all.isEmpty)
                      _EmptyCard(
                        message: schedule.isEmpty
                            ? 'Set your weekly hours to start receiving requests.'
                            : 'No requests yet. You will be notified during your scheduled hours.',
                      )
                    else
                      for (final item in all.take(3))
                        _RequestCard(
                          assignment: item,
                          volunteerName: profile?.displayName ?? 'Volunteer',
                          volunteerCatalogId: catalogId,
                          compact: true,
                        ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.catalogId,
    required this.filterIndex,
    required this.onFilterChanged,
    required this.volunteerName,
    this.onAssignmentUpdated,
  });

  final String catalogId;
  final int filterIndex;
  final ValueChanged<int> onFilterChanged;
  final String volunteerName;
  final VoidCallback? onAssignmentUpdated;

  List<VolunteerAssignment> _filter(List<VolunteerAssignment> all) {
    return switch (filterIndex) {
      1 => all.where((a) => a.status == 'accepted').toList(),
      2 => all
          .where((a) =>
              a.status == 'completed' ||
              a.status == 'declined' ||
              a.status == 'cancelled')
          .toList(),
      _ => all
          .where((a) =>
              a.status == 'pending' ||
              a.status == 'follow_up' ||
              a.status == 'counter_proposed')
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (catalogId.isEmpty) {
      return const Center(child: Text('Complete volunteer setup first.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('New')),
              ButtonSegment(value: 1, label: Text('Active')),
              ButtonSegment(value: 2, label: Text('History')),
            ],
            selected: {filterIndex},
            onSelectionChanged: (s) => onFilterChanged(s.first),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<VolunteerAssignment>>(
            stream: VolunteerRepository.instance.watchAssignments(catalogId),
            builder: (context, snapshot) {
              final all = snapshot.data ?? [];
              final items = _filter(all);

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      filterIndex == 0
                          ? 'No new requests right now.'
                          : filterIndex == 1
                              ? 'No active assignments.'
                              : 'No completed, declined, or cancelled requests yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) => _RequestCard(
                  assignment: items[index],
                  volunteerName: volunteerName,
                  volunteerCatalogId: catalogId,
                  onStatusChanged: (status) {
                    if (status == 'accepted') onFilterChanged(1);
                    if (status == 'accepted' || status == 'completed') {
                      onAssignmentUpdated?.call();
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({
    required this.catalogId,
    required this.volunteerName,
  });

  final String catalogId;
  final String volunteerName;

  @override
  Widget build(BuildContext context) {
    if (catalogId.isEmpty) {
      return const Center(child: Text('Complete volunteer setup first.'));
    }

    return StreamBuilder<List<VolunteerMessageThread>>(
      stream: VolunteerRepository.instance.watchMessageThreads(catalogId),
      builder: (context, snapshot) {
        final threads = snapshot.data ?? [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (threads.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'When families message you, conversations appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                      height: 1.4,
                    ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: threads.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final thread = threads[index];
            final name = thread.familyDisplayName ?? 'Family member';
            return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFF439A7D).withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Color(0xFF439A7D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      thread.updatedAt != null
                          ? 'Updated ${_formatRelative(thread.updatedAt!)}'
                          : 'Tap to open chat',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VolunteerFamilyChatPage(
                            familyUserId: thread.familyUserId,
                            volunteerCatalogId: thread.volunteerCatalogId,
                            volunteerName: volunteerName,
                            familyDisplayName: name,
                          ),
                        ),
                      );
                    },
                  ),
                );
          },
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.lane,
    required this.now,
    required this.availableNow,
    required this.onEditSchedule,
    required this.onChangeLane,
    required this.onSignOut,
  });

  final UserProfile? profile;
  final CatalogVolunteer? lane;
  final DateTime now;
  final bool availableNow;
  final VoidCallback onEditSchedule;
  final VoidCallback onChangeLane;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule =
        profile?.volunteerSchedule() ?? VolunteerAvailabilitySchedule.empty;
    final activeBlock =
        profile?.availabilityBlocks.withoutExpired(now).activeBlockLabel(now);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF439A7D).withValues(alpha: 0.15),
            child: Text(
              (profile?.displayName ?? '').isNotEmpty
                  ? profile!.displayName[0].toUpperCase()
                  : '?',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF439A7D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            profile?.displayName ?? 'Volunteer',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (profile?.email != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              profile!.email!,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _ProfileSection(
          title: 'Your impact',
          child: Text(
            (profile?.volunteerStats ?? const VolunteerProfileStats())
                .summaryLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: 'Weekly availability',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    availableNow ? Icons.circle : Icons.circle_outlined,
                    size: 12,
                    color: availableNow ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedule.statusLabel(now),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (schedule.isEmpty)
                Text(
                  'No hours set yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                )
              else
                Text(
                  schedule.summaryLines(),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              if (activeBlock != null) ...[
                const SizedBox(height: 10),
                Text(
                  activeBlock,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onEditSchedule,
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const Text('Edit weekly hours'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: 'Volunteer lane',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lane?.role ?? 'Not set up yet',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (lane != null) ...[
                const SizedBox(height: 4),
                Text(
                  lane!.specialties.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onChangeLane,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Change service type'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: 'Account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Account type'),
                subtitle: const Text('Volunteer'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: onSignOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'Sign out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black54,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
            ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.assignment,
    required this.volunteerName,
    required this.volunteerCatalogId,
    this.compact = false,
    this.onStatusChanged,
  });

  final VolunteerAssignment assignment;
  final String volunteerName;
  final String volunteerCatalogId;
  final bool compact;
  final ValueChanged<String>? onStatusChanged;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VolunteerRequestDetailPage(
          assignment: assignment,
          volunteerName: volunteerName,
          volunteerCatalogId: volunteerCatalogId,
          onStatusChanged: onStatusChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = assignment.routeSummary;
    final location = assignment.locationSummary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(context),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assignment.familyName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  _StatusChip(status: assignment.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                assignment.serviceTypeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF439A7D),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (assignment.isUrgent) ...[
                const SizedBox(height: 6),
                Text(
                  'URGENT · all lane volunteers notified',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                assignment.whenLabel(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              if (assignment.needsNow)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'ASAP',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined,
                        size: 16, color: Colors.black45),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                              height: 1.35,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              if (route.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.directions_outlined,
                        size: 16, color: Colors.black45),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.35,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              if (assignment.notes != null) ...[
                const SizedBox(height: 6),
                Text(
                  assignment.notes!,
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black87,
                        height: 1.35,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Tap for full details',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.black38,
                    ),
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                _RequestActions(
                  assignment: assignment,
                  volunteerName: volunteerName,
                  volunteerCatalogId: volunteerCatalogId,
                  onStatusChanged: onStatusChanged,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestActions extends StatefulWidget {
  const _RequestActions({
    required this.assignment,
    required this.volunteerName,
    required this.volunteerCatalogId,
    this.onStatusChanged,
  });

  final VolunteerAssignment assignment;
  final String volunteerName;
  final String volunteerCatalogId;
  final ValueChanged<String>? onStatusChanged;

  @override
  State<_RequestActions> createState() => _RequestActionsState();
}

class _RequestActionsState extends State<_RequestActions> {
  bool _updating = false;

  Future<void> _proposeCounterTime() async {
    final proposed = await showCounterTimeDialog(
      context,
      familyName: widget.assignment.familyName,
    );
    if (proposed == null || !mounted) return;

    setState(() => _updating = true);
    try {
      await VolunteerRepository.instance.proposeCounterTime(
        familyUserId: widget.assignment.familyUserId,
        requestId: widget.assignment.requestId,
        counterScheduledAt: proposed,
        volunteerUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        volunteerName: widget.volunteerName,
      );
      if (!mounted) return;
      widget.onStatusChanged?.call('counter_proposed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Counter time sent — waiting for the family to respond.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send counter time: $e')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (status == 'accepted') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accept this request?'),
          content: Text(
            'You will be helping ${widget.assignment.familyName} for '
            '${widget.assignment.durationLabel}. '
            'Your calendar will be blocked for that time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _updating = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await VolunteerRepository.instance.updateAssignmentStatus(
        familyUserId: widget.assignment.familyUserId,
        requestId: widget.assignment.requestId,
        status: status,
        volunteerUid: uid,
        volunteerName: widget.volunteerName,
      );
      if (!mounted) return;
      widget.onStatusChanged?.call(status);
      if (status == 'accepted') {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Request accepted'),
            content: Text(
              'You are now helping ${widget.assignment.familyName} for '
              '${widget.assignment.durationLabel}. '
              'Your calendar is blocked until you mark the visit complete. '
              'Open the Active tab to message them.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('View Active'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request marked as $status.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $e')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final status = assignment.status;

    if (status == 'pending' || status == 'follow_up') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _updating ? null : () => _updateStatus('accepted'),
                  child: _updating
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _updating ? null : () => _updateStatus('declined'),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _updating ? null : _proposeCounterTime,
            icon: const Icon(Icons.schedule_send_outlined, size: 18),
            label: const Text('Suggest another time'),
          ),
        ],
      );
    }

    if (status == 'accepted') {
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _updating ? null : () => _updateStatus('completed'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF439A7D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                minimumSize: const Size(0, 40),
              ),
              child: _updating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Mark complete',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VolunteerFamilyChatPage(
                      familyUserId: assignment.familyUserId,
                      volunteerCatalogId: assignment.volunteerCatalogId ??
                          widget.volunteerCatalogId,
                      volunteerName: widget.volunteerName,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                minimumSize: const Size(0, 40),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Message',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' => Colors.green.shade700,
      'completed' => Colors.blue.shade700,
      'declined' => Colors.red.shade700,
      'cancelled' => Colors.grey.shade700,
      'follow_up' => Colors.purple.shade700,
      'counter_proposed' => Colors.purple.shade700,
      _ => Colors.orange.shade800,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _formatRelative(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
