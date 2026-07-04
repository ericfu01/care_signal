import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'family_models.dart';
import 'family_repository.dart';
import 'volunteer_background_check.dart';
import 'volunteer_background_check_repository.dart';
import 'volunteer_home_page.dart';
import 'volunteer_setup_page.dart';

/// Blocks volunteer access until a background check is submitted and approved.
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
          content: Text('Consent to the background check to continue.'),
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
            );
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
  const _PendingView({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.verified_user_outlined,
          size: 72,
          color: _VolunteerBackgroundCheckPageState._accent,
        ),
        const SizedBox(height: 20),
        Text(
          'Running your background check',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Thanks, $displayName. We are screening your application to help keep '
          'families safe. This usually takes a few moments.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.black54,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 28),
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
            'You will be able to set up your volunteer profile and respond to '
            'requests once screening is complete.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
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
            'Background check required',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Before you can volunteer with families or host peer groups, we run a '
            'background check to help keep the community safe.',
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
              child: Text(
                rejectionNote?.trim().isNotEmpty == true
                    ? rejectionNote!.trim()
                    : 'Your previous application could not be approved. '
                        'Review your information and submit again, or contact support.',
                style: TextStyle(color: Colors.red.shade900, height: 1.35),
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
              'I authorize Care Signal to run a background check and confirm the '
              'information above is accurate.',
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
                : Text(rejected ? 'Submit again' : 'Submit for screening'),
          ),
        ],
      ),
    );
  }
}
