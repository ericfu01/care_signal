import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_navigation.dart';
import 'staff_invite_service.dart';

/// Redeem a staff access code. Must be signed in first.
class StaffInvitePage extends StatefulWidget {
  const StaffInvitePage({super.key});

  @override
  State<StaffInvitePage> createState() => _StaffInvitePageState();
}

class _StaffInvitePageState extends State<StaffInvitePage> {
  final _codeController = TextEditingController();
  bool _redeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_redeeming) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in first, then enter your staff code.'),
        ),
      );
      return;
    }

    setState(() => _redeeming = true);
    try {
      await StaffInviteService.instance.redeemInvite(_codeController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff access activated.')),
      );
      await navigateAfterAuth(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not redeem code: $e')),
      );
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff access'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Enter staff code',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            signedIn
                ? 'Enter the one-time code from a Care Signal administrator. '
                    'You will be taken to the staff dashboard.'
                : 'You must sign in first. Create or use a Care Signal account, '
                    'then open Profile → Staff access code and enter the code.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),
          if (!signedIn) ...[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to sign in'),
            ),
          ] else ...[
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Staff access code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              onSubmitted: (_) => _redeem(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _redeeming ? null : _redeem,
              child: Text(_redeeming ? 'Verifying…' : 'Activate staff access'),
            ),
          ],
        ],
      ),
    );
  }
}
