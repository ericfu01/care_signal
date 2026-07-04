import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_deletion_service.dart';
import 'app_config_service.dart';
import 'auth_gate.dart';
import 'data_export_service.dart';
import 'staff_repository.dart';

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to export your data.')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final result = await DataExportService.instance.exportAndShare();
      if (!mounted) return;
      final checkInLine = result.checkInCount == 0
          ? 'no check-ins yet, but your profile was included'
          : '${result.checkInCount} check-in'
              '${result.checkInCount == 1 ? '' : 's'} included';
      final message = switch (result.delivery) {
        DataExportDelivery.shareSheet => 'Export ready — $checkInLine.',
        DataExportDelivery.clipboard =>
          'Export copied to clipboard ($checkInLine). Paste into Notes or Mail.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download a copy of your check-ins, stress summaries, and '
            'profile information. When sharing works, you get a JSON file; '
            'otherwise a readable text summary is copied to your clipboard.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            'Includes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...[
            'Account and family profile details',
            'Family member names (if in a family)',
            'Wellness check-in history (up to 500 most recent)',
            'Stress source summary counts',
          ].map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: Theme.of(context).textTheme.bodyMedium),
                  Expanded(
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: signedIn && !_exporting ? _export : null,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_exporting ? 'Preparing export…' : 'Export my data'),
          ),
          if (!signedIn) ...[
            const SizedBox(height: 12),
            Text(
              'Sign in to export data from your account.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _feedbackController = TextEditingController();
  bool _sending = false;
  String _supportEmail = AppConfig.defaultSupportEmail;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSupportEmail());
  }

  Future<void> _loadSupportEmail() async {
    final config = await AppConfigService.instance.loadConfig();
    if (!mounted) return;
    setState(() => _supportEmail = config.supportEmail);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Care Signal support',
      },
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email us at $_supportEmail')),
      );
    }
  }

  Future<void> _sendFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);
    try {
      await StaffRepository.instance.submitFeedback(
        message: message,
        email: FirebaseAuth.instance.currentUser?.email,
      );
      if (!mounted) return;
      _feedbackController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your feedback was sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send feedback: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Get help',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Having trouble with Care Signal? Try the steps below or reach out '
            'to our team.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            'Common issues',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Update to the latest app version from your app store.\n'
            '• Check your internet connection for sync and sign-in.\n'
            '• Force-close and reopen the app if the screen freezes.\n'
            '• Restart your device if check-ins or trends fail to load.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 24),
          Text(
            'Contact support',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Email $_supportEmail with a short description of the problem. '
            'We typically reply within one business day.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _emailSupport,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email support'),
          ),
          const SizedBox(height: 28),
          Text(
            'Send feedback',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackController,
            decoration: const InputDecoration(
              labelText: 'What can we improve?',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _sendFeedback,
            icon: const Icon(Icons.feedback_outlined),
            label: Text(_sending ? 'Sending…' : 'Submit feedback'),
          ),
        ],
      ),
    );
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _deleting = false;
  bool _confirmed = false;

  Future<void> _delete() async {
    if (!_confirmed || _deleting) return;
    setState(() => _deleting = true);
    try {
      await AccountDeletionService.instance.deleteCurrentAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Delete your account',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This permanently deletes your sign-in, check-ins, notifications, '
            'profile photo, partner wellness share, and peer group memberships. '
            'Your display name becomes "Deleted user" for any family records that '
            'still reference you. Export your data first if you want a copy.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            onChanged: (value) =>
                setState(() => _confirmed = value ?? false),
            title: const Text('I understand this cannot be undone'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: _confirmed && !_deleting ? _delete : null,
            child: Text(_deleting ? 'Deleting…' : 'Delete my account'),
          ),
        ],
      ),
    );
  }
}
