import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'community_event_models.dart';
import 'community_event_repository.dart';
import 'family_models.dart';
import 'staff_invite_service.dart';
import 'staff_repository.dart';

/// Staff operations: volunteer screening, events, feedback.
class StaffHomePage extends StatefulWidget {
  const StaffHomePage({super.key});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Care Signal Staff'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => AuthSession.confirmAndSignOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _BackgroundCheckTab(),
          _EventsAdminTab(),
          _FeedbackTab(),
          _TeamTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            selectedIcon: Icon(Icons.verified_user_rounded),
            label: 'Screening',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.feedback_outlined),
            selectedIcon: Icon(Icons.feedback_rounded),
            label: 'Feedback',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_add_outlined),
            selectedIcon: Icon(Icons.group_add_rounded),
            label: 'Team',
          ),
        ],
      ),
    );
  }
}

class _BackgroundCheckTab extends StatelessWidget {
  const _BackgroundCheckTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserProfile>>(
      stream: StaffRepository.instance.watchPendingBackgroundChecks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = snapshot.data ?? [];
        if (pending.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No volunteer screenings waiting for review.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final profile = pending[index];
            return Card(
              child: ListTile(
                title: Text(profile.displayName),
                subtitle: Text(profile.email ?? profile.uid),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Reject',
                      onPressed: () => _review(context, profile, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    IconButton(
                      tooltip: 'Approve',
                      onPressed: () => _review(context, profile, true),
                      icon: Icon(Icons.check_rounded, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _review(
    BuildContext context,
    UserProfile profile,
    bool approve,
  ) async {
    try {
      await StaffRepository.instance.reviewBackgroundCheck(
        volunteerUid: profile.uid,
        approve: approve,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Approved ${profile.displayName}'
                : 'Rejected ${profile.displayName}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update screening: $e')),
      );
    }
  }
}

class _EventsAdminTab extends StatefulWidget {
  const _EventsAdminTab();

  @override
  State<_EventsAdminTab> createState() => _EventsAdminTabState();
}

class _EventsAdminTabState extends State<_EventsAdminTab> {
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isOnline = true;
  DateTime _startsAt = DateTime.now().add(const Duration(days: 7));
  bool _creating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startsAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startsAt.hour,
        _startsAt.minute,
      );
    });
  }

  Future<void> _createEvent() async {
    final title = _titleController.text.trim();
    final timeDisplay = _timeController.text.trim();
    if (title.isEmpty || timeDisplay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title and time display.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      await CommunityEventRepository.instance.createEvent(
        title: title,
        startsAt: _startsAt,
        isOnline: _isOnline,
        timeDisplay: timeDisplay,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      _titleController.clear();
      _timeController.clear();
      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event published.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create event: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Create community event',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _timeController,
          decoration: const InputDecoration(
            labelText: 'Time display (e.g. Wed · 6:30 p.m.)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Starts on'),
          subtitle: Text(
            '${_startsAt.month}/${_startsAt.day}/${_startsAt.year}',
          ),
          trailing: TextButton(onPressed: _pickDate, child: const Text('Change')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Online event'),
          value: _isOnline,
          onChanged: (value) => setState(() => _isOnline = value),
        ),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _creating ? null : _createEvent,
          child: Text(_creating ? 'Publishing…' : 'Publish event'),
        ),
        const SizedBox(height: 28),
        Text(
          'Published events',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<CommunityEvent>>(
          stream: CommunityEventRepository.instance.watchAllEventsForStaff(),
          builder: (context, snapshot) {
            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return const Text('No events yet.');
            }
            return Column(
              children: events.map((event) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(event.title),
                    subtitle: Text(
                      '${event.timeDisplay} · ${event.signupCount} signed up',
                    ),
                    children: [
                      StreamBuilder<List<CommunityEventSignup>>(
                        stream: CommunityEventRepository.instance
                            .watchSignups(event.id),
                        builder: (context, signupSnap) {
                          final signups = signupSnap.data ?? [];
                          if (signups.isEmpty) {
                            return const ListTile(title: Text('No signups yet'));
                          }
                          return Column(
                            children: signups
                                .map(
                                  (signup) => ListTile(
                                    title: Text(signup.name),
                                    subtitle: Text(
                                      '${signup.email} · party of ${signup.familyCount}',
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: StaffRepository.instance.watchFeedback(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No feedback submitted yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            return Card(
              child: ListTile(
                title: Text((data['message'] as String?) ?? ''),
                subtitle: Text((data['email'] as String?) ?? 'Signed-in user'),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamTab extends StatefulWidget {
  const _TeamTab();

  @override
  State<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<_TeamTab> {
  final _emailController = TextEditingController();
  bool _creating = false;
  String? _latestCode;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createInvite() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final email = _emailController.text.trim();
      final code = await StaffInviteService.instance.createInvite(
        email: email.isEmpty ? null : email,
      );
      if (!mounted) return;
      setState(() => _latestCode = code);
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            email.isEmpty
                ? 'Staff code created: $code'
                : 'Staff code emailed to $email (also shown below).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Invite staff',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create a one-time access code for a teammate. Codes expire in 7 days. '
          'Optionally bind to an email — if SendGrid is configured, the code is emailed.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email (optional)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _creating ? null : _createInvite,
          icon: const Icon(Icons.add_moderator_outlined),
          label: Text(_creating ? 'Creating…' : 'Create staff code'),
        ),
        if (_latestCode != null) ...[
          const SizedBox(height: 16),
          SelectableText(
            'Latest code: $_latestCode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Recent invites',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: StaffRepository.instance.watchStaffInvites(),
          builder: (context, snapshot) {
            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return const Text('No staff invites yet.');
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final status = (data['status'] as String?) ?? 'pending';
                final email = (data['email'] as String?) ?? 'Any email';
                return Card(
                  child: ListTile(
                    title: Text(doc.id),
                    subtitle: Text('$email · $status'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
