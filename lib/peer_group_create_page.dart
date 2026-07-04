import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'peer_group_repository.dart';
import 'peer_group_volunteer_tab.dart';

/// Volunteer flow to create a new peer support group.
class PeerGroupCreatePage extends StatefulWidget {
  const PeerGroupCreatePage({super.key});

  @override
  State<PeerGroupCreatePage> createState() => _PeerGroupCreatePageState();
}

class _PeerGroupCreatePageState extends State<PeerGroupCreatePage> {
  final _titleController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _modeController = TextEditingController();
  final _membersController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _scheduleController.dispose();
    _modeController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final title = _titleController.text.trim();
    final schedule = _scheduleController.text.trim();
    final mode = _modeController.text.trim();
    if (title.isEmpty || schedule.isEmpty || mode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a title, schedule, and how the group meets.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await PeerGroupRepository.instance.createGroup(
        hostUid: uid,
        title: title,
        schedule: schedule,
        mode: mode,
        membersLabel: _membersController.text.trim().isEmpty
            ? 'Open to families'
            : _membersController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created “$title”.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create group: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create peer group'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Start a support group',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Families can request to join after you publish. You can invite '
              'members by email and approve join requests from your group page.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Group name',
                border: OutlineInputBorder(),
                hintText: 'Caregiver coffee hour',
              ),
              textInputAction: TextInputAction.next,
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scheduleController,
              decoration: const InputDecoration(
                labelText: 'Schedule',
                border: OutlineInputBorder(),
                hintText: 'Wednesdays · 10:00 a.m.',
              ),
              textInputAction: TextInputAction.next,
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modeController,
              decoration: const InputDecoration(
                labelText: 'How you meet',
                border: OutlineInputBorder(),
                hintText: 'Online · Zoom',
              ),
              textInputAction: TextInputAction.next,
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _membersController,
              decoration: const InputDecoration(
                labelText: 'Members label (optional)',
                border: OutlineInputBorder(),
                hintText: 'Open to families',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
              enabled: !_saving,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: kPeerGroupAccent,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create group'),
            ),
          ],
        ),
      ),
    );
  }
}
