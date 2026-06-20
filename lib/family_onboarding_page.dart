import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_repository.dart';

/// First-time setup: confirm name, create a family, or join with invite.
class FamilyOnboardingPage extends StatefulWidget {
  const FamilyOnboardingPage({
    super.key,
    required this.initialDisplayName,
  });

  final String initialDisplayName;

  @override
  State<FamilyOnboardingPage> createState() => _FamilyOnboardingPageState();
}

class _FamilyOnboardingPageState extends State<FamilyOnboardingPage> {
  static const Color _accent = Color(0xFF439A7D);

  final _nameController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _inviteController = TextEditingController();

  _OnboardingMode _mode = _OnboardingMode.create;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialDisplayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _familyNameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await FamilyRepository.instance.updateDisplayName(user.uid, name);

      if (_mode == _OnboardingMode.create) {
        await FamilyRepository.instance.createFamily(
          uid: user.uid,
          familyName: _familyNameController.text.trim(),
        );
      } else {
        await FamilyRepository.instance.joinFamilyWithInvite(
          uid: user.uid,
          inviteInput: _inviteController.text,
        );
      }

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Your family')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set up Care Signal',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use your real name so family members recognize you.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SegmentedButton<_OnboardingMode>(
                segments: const [
                  ButtonSegment(
                    value: _OnboardingMode.create,
                    label: Text('Start family'),
                    icon: Icon(Icons.home_rounded),
                  ),
                  ButtonSegment(
                    value: _OnboardingMode.join,
                    label: Text('Join family'),
                    icon: Icon(Icons.link_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (set) => setState(() => _mode = set.first),
              ),
              const SizedBox(height: 20),
              if (_mode == _OnboardingMode.create) ...[
                TextField(
                  controller: _familyNameController,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Family name (optional)',
                    hintText: 'e.g. The Martinez family',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will get an invite link to share after setup.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _inviteController,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Invite code or link',
                    hintText: 'Paste link or enter 8-character code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _finishSetup,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _mode == _OnboardingMode.create
                            ? 'Create family'
                            : 'Join family',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OnboardingMode { create, join }
