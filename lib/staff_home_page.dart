import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'community_event_models.dart';
import 'community_event_repository.dart';
import 'family_models.dart';
import 'feedback_models.dart';
import 'staff_feedback_detail_page.dart';
import 'staff_invite_service.dart';
import 'staff_repository.dart';
import 'volunteer_background_check_repository.dart';

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
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final profile = pending[index];
            final submitted = profile.backgroundCheckSubmittedAt;
            final submittedLabel = submitted == null
                ? 'Submitted — pending review'
                : 'Submitted ${submitted.month}/${submitted.day}/${submitted.year}';
            return Card(
              child: ListTile(
                title: Text(profile.displayName),
                subtitle: Text('${profile.email ?? profile.uid}\n$submittedLabel'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openReview(context, profile),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openReview(BuildContext context, UserProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BackgroundCheckReviewSheet(profile: profile),
    );
  }
}

class _BackgroundCheckReviewSheet extends StatefulWidget {
  const _BackgroundCheckReviewSheet({required this.profile});

  final UserProfile profile;

  @override
  State<_BackgroundCheckReviewSheet> createState() =>
      _BackgroundCheckReviewSheetState();
}

class _BackgroundCheckReviewSheetState
    extends State<_BackgroundCheckReviewSheet> {
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _review(bool approve) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await StaffRepository.instance.reviewBackgroundCheck(
        volunteerUid: widget.profile.uid,
        approve: approve,
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Approved ${widget.profile.displayName}'
                : 'Rejected ${widget.profile.displayName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update screening: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Review screening',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              profile.email ?? profile.uid,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<VolunteerBackgroundCheckApplication?>(
              future: VolunteerBackgroundCheckRepository.instance
                  .fetchCurrentApplication(profile.uid),
              builder: (context, snapshot) {
                final app = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (app == null) {
                  return const Text('No application details found.');
                }
                final dob = app.dateOfBirth;
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('Legal name',
                            '${app.legalFirstName} ${app.legalLastName}'),
                        _detailRow(
                          'Date of birth',
                          '${dob.month}/${dob.day}/${dob.year}',
                        ),
                        _detailRow(
                          'Address',
                          '${app.streetAddress}, ${app.city}, ${app.state} ${app.zip}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note to volunteer',
                hintText: 'Required if rejecting (what to fix)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _review(false),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : () => _review(true),
                    child: Text(_saving ? 'Saving…' : 'Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          Text(value),
        ],
      ),
    );
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

  Future<void> _editEvent(CommunityEvent event) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => _EditEventDialog(event: event),
    );
    if (!mounted || updated != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event updated.')),
    );
  }

  Future<void> _cancelEvent(CommunityEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel event?'),
        content: Text(
          '"${event.title}" will be removed from Support for families. '
          'Signup records are kept for staff.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CommunityEventRepository.instance.cancelEvent(event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel event: $e')),
      );
    }
  }

  Future<void> _restoreEvent(CommunityEvent event) async {
    try {
      await CommunityEventRepository.instance.restoreEvent(event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event restored and published.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restore event: $e')),
      );
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
          'All events',
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
                final status = event.cancelled
                    ? 'Cancelled'
                    : event.published
                        ? 'Published'
                        : 'Unpublished';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(event.title),
                    subtitle: Text(
                      '$status · ${event.timeDisplay} · ${event.signupCount} signed up',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: event.cancelled
                                  ? null
                                  : () => _editEvent(event),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                            if (event.cancelled)
                              OutlinedButton.icon(
                                onPressed: () => _restoreEvent(event),
                                icon: const Icon(Icons.restore, size: 18),
                                label: const Text('Restore'),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () => _cancelEvent(event),
                                icon: const Icon(Icons.cancel_outlined, size: 18),
                                label: const Text('Cancel'),
                              ),
                          ],
                        ),
                      ),
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

class _EditEventDialog extends StatefulWidget {
  const _EditEventDialog({required this.event});

  final CommunityEvent event;

  @override
  State<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<_EditEventDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _timeController;
  late final TextEditingController _descriptionController;
  late bool _isOnline;
  late bool _published;
  late DateTime _startsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event.title);
    _timeController = TextEditingController(text: event.timeDisplay);
    _descriptionController =
        TextEditingController(text: event.description ?? '');
    _isOnline = event.isOnline;
    _published = event.published;
    _startsAt = event.startsAt;
  }

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
      initialDate: _startsAt.isBefore(DateTime.now()) ? DateTime.now() : _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final timeDisplay = _timeController.text.trim();
    if (title.isEmpty || timeDisplay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title and time display.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await CommunityEventRepository.instance.updateEvent(
        eventId: widget.event.id,
        title: title,
        startsAt: _startsAt,
        isOnline: _isOnline,
        timeDisplay: timeDisplay,
        description: _descriptionController.text.trim(),
        published: _published,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update event: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit event'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  labelText: 'Time display',
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
                trailing:
                    TextButton(onPressed: _pickDate, child: const Text('Change')),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Online event'),
                value: _isOnline,
                onChanged: (value) => setState(() => _isOnline = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                subtitle: const Text('Visible on Support when upcoming'),
                value: _published,
                onChanged: (value) => setState(() => _published = value),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  /// 0 = open, 1 = resolved, 2 = all
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Open')),
              ButtonSegment(value: 1, label: Text('Resolved')),
              ButtonSegment(value: 2, label: Text('All')),
            ],
            selected: {_filter},
            onSelectionChanged: (selection) {
              setState(() => _filter = selection.first);
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FeedbackRecord>>(
            stream: StaffRepository.instance.watchFeedback(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data ?? [];
              final items = switch (_filter) {
                0 => all.where((f) => !f.isResolved).toList(),
                1 => all.where((f) => f.isResolved).toList(),
                _ => all,
              };
              if (all.isEmpty) {
                return const Center(child: Text('No feedback submitted yet.'));
              }
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    _filter == 0
                        ? 'No open feedback.'
                        : 'No resolved feedback yet.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final feedback = items[index];
                  final preview = feedback.message.trim();
                  final title = preview.isEmpty
                      ? '(No message)'
                      : (preview.length > 80
                          ? '${preview.substring(0, 80)}…'
                          : preview);
                  final photoLabel = feedback.hasPhotos
                      ? ' · ${feedback.photoUrls.length} photo'
                          '${feedback.photoUrls.length == 1 ? '' : 's'}'
                      : '';
                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle: Text(
                        '${feedback.isResolved ? 'Resolved' : 'Open'} · '
                        '${feedback.email?.isNotEmpty == true ? feedback.email! : 'Signed-in user'}'
                        '$photoLabel',
                      ),
                      trailing: Icon(
                        feedback.isResolved
                            ? Icons.check_circle_outline
                            : feedback.hasPhotos
                                ? Icons.photo_library_outlined
                                : Icons.chevron_right,
                        color: feedback.isResolved ? Colors.green.shade700 : null,
                      ),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                StaffFeedbackDetailPage(feedback: feedback),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
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
