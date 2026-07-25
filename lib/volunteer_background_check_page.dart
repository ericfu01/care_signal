import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'family_models.dart';
import 'family_repository.dart';
import 'volunteer_background_check.dart';
import 'volunteer_background_check_repository.dart';
import 'volunteer_home_page.dart';
import 'volunteer_setup_page.dart';

/// Blocks volunteer access until volunteer screening is submitted and approved.
class VolunteerBackgroundCheckPage extends StatefulWidget {
  const VolunteerBackgroundCheckPage({super.key});

  @override
  State<VolunteerBackgroundCheckPage> createState() =>
      _VolunteerBackgroundCheckPageState();
}

class _VolunteerBackgroundCheckPageState
    extends State<VolunteerBackgroundCheckPage> {
  static const _accent = Color(0xFF439A7D);

  final _legalFirstController = TextEditingController();
  final _legalLastController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _consent = false;
  bool _submitting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _legalFirstController.dispose();
    _legalLastController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _prefillFromPreviousApplication() async {
    if (_prefilled) return;
    _prefilled = true;
    try {
      final previous = await VolunteerBackgroundCheckRepository.instance
          .fetchCurrentApplication();
      if (previous == null || !mounted) return;
      setState(() {
        _legalFirstController.text = previous.legalFirstName;
        _legalLastController.text = previous.legalLastName;
        _streetController.text = previous.streetAddress;
        _cityController.text = previous.city;
        _stateController.text = previous.state;
        _zipController.text = previous.zip;
        _dateOfBirth = previous.dateOfBirth;
      });
    } catch (_) {}
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ??
        DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your date of birth.')),
      );
      return;
    }
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirm consent to continue.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await VolunteerBackgroundCheckRepository.instance.submitApplication(
        VolunteerBackgroundCheckApplication(
          legalFirstName: _legalFirstController.text,
          legalLastName: _legalLastController.text,
          dateOfBirth: _dateOfBirth!,
          streetAddress: _streetController.text,
          city: _cityController.text,
          state: _stateController.text,
          zip: _zipController.text,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openVolunteerHome(UserProfile profile) {
    final next = profile.volunteerProfileComplete
        ? const VolunteerHomePage()
        : const VolunteerSetupPage();
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => next),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to continue.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer screening'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => AuthSession.signOutAndNavigate(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: FamilyRepository.instance.watchUserProfile(uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final status =
              VolunteerBackgroundCheckStatus.normalize(profile?.backgroundCheckStatus);

          if (VolunteerBackgroundCheckStatus.isApproved(status) &&
              profile != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _openVolunteerHome(profile);
            });
            return const Center(child: CircularProgressIndicator());
          }

          if (VolunteerBackgroundCheckStatus.isPending(status)) {
            return _PendingView(
              displayName: profile?.displayName ?? 'Volunteer',
              submittedAt: profile?.backgroundCheckSubmittedAt,
            );
          }

          if (VolunteerBackgroundCheckStatus.isRejected(status)) {
            unawaited(_prefillFromPreviousApplication());
          }

          return _ApplicationForm(
            status: status,
            rejectionNote: profile?.backgroundCheckNote,
            legalFirstController: _legalFirstController,
            legalLastController: _legalLastController,
            streetController: _streetController,
            cityController: _cityController,
            stateController: _stateController,
            zipController: _zipController,
            dateOfBirth: _dateOfBirth,
            consent: _consent,
            submitting: _submitting,
            onPickDateOfBirth: _pickDateOfBirth,
            onConsentChanged: (value) => setState(() => _consent = value),
            onSubmit: _submit,
          );
        },
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView({
    required this.displayName,
    this.submittedAt,
  });

  final String displayName;
  final DateTime? submittedAt;

  String _formatSubmittedAt() {
    final value = submittedAt;
    if (value == null) return 'Submitted — waiting for review';
    final local = value.toLocal();
    return 'Submitted ${local.month}/${local.day}/${local.year} '
        'at ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.hourglass_top_rounded,
          size: 72,
          color: _VolunteerBackgroundCheckPageState._accent,
        ),
        const SizedBox(height: 20),
        Text(
          'Under review',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Thanks, $displayName. Your volunteer screening was submitted and is '
          'waiting for a Care Signal staff member to review it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.black54,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatSubmittedAt(),
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF439A7D).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF439A7D).withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            'What happens next\n'
            '• Staff reviews your application\n'
            '• You’ll get an in-app notification when it’s approved or needs changes\n'
            '• After approval, you can finish volunteer setup and help families',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'You can close the app and come back anytime — this screen updates automatically.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
        ),
      ],
    );
  }
}

class _ApplicationForm extends StatelessWidget {
  const _ApplicationForm({
    required this.status,
    required this.rejectionNote,
    required this.legalFirstController,
    required this.legalLastController,
    required this.streetController,
    required this.cityController,
    required this.stateController,
    required this.zipController,
    required this.dateOfBirth,
    required this.consent,
    required this.submitting,
    required this.onPickDateOfBirth,
    required this.onConsentChanged,
    required this.onSubmit,
  });

  final String status;
  final String? rejectionNote;
  final TextEditingController legalFirstController;
  final TextEditingController legalLastController;
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController zipController;
  final DateTime? dateOfBirth;
  final bool consent;
  final bool submitting;
  final VoidCallback onPickDateOfBirth;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rejected = VolunteerBackgroundCheckStatus.isRejected(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Volunteer screening required',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Before you can volunteer with families or host peer groups, Care Signal '
            'staff review your application. This is an internal safety screen — not '
            'a third-party background check service.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          if (rejected) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Action needed — application not approved',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rejectionNote?.trim().isNotEmpty == true
                        ? rejectionNote!.trim()
                        : 'Your previous application could not be approved. '
                            'Update your information below and resubmit.',
                    style: TextStyle(color: Colors.red.shade900, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your previous details are filled in where possible. '
                    'Fix anything noted above, confirm consent, then resubmit.',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Legal name',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: legalFirstController,
            decoration: const InputDecoration(
              labelText: 'Legal first name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            enabled: !submitting,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: legalLastController,
            decoration: const InputDecoration(
              labelText: 'Legal last name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            enabled: !submitting,
          ),
          const SizedBox(height: 16),
          Text(
            'Date of birth',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: submitting ? null : onPickDateOfBirth,
            child: Text(
              dateOfBirth == null
                  ? 'Select date of birth'
                  : '${dateOfBirth!.month}/${dateOfBirth!.day}/${dateOfBirth!.year}',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Home address',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: streetController,
            decoration: const InputDecoration(
              labelText: 'Street address',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            enabled: !submitting,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cityController,
            decoration: const InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            enabled: !submitting,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !submitting,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: zipController,
                  decoration: const InputDecoration(
                    labelText: 'ZIP',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !submitting,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: consent,
            onChanged: submitting ? null : (v) => onConsentChanged(v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I confirm the information above is accurate and authorize Care Signal '
              'staff to review my volunteer screening application.',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: _VolunteerBackgroundCheckPageState._accent,
            ),
            child: submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    rejected ? 'Resubmit application' : 'Submit for screening',
                  ),
          ),
        ],
      ),
    );
  }
}
