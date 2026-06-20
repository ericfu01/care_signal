import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data_export_service.dart';

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

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

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
            'Email care.signal.support@example.com with a short description '
            'of the problem and your app version. We typically reply within '
            'one business day.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Feedback form is not connected yet.'),
                ),
              );
            },
            icon: const Icon(Icons.feedback_outlined),
            label: const Text('Send feedback'),
          ),
        ],
      ),
    );
  }
}
