import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_type.dart';
import 'auth_error_support.dart';
import 'auth_navigation.dart';
import 'family_repository.dart';
import 'saved_login_email.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _accountType = AccountType.caregiver;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill in all fields.')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
      final uid = credential.user?.uid;
      if (uid != null) {
        await FamilyRepository.instance.upsertUserProfile(
          uid: uid,
          displayName: name,
          email: email,
          accountType: _accountType,
        );
      }
      try {
        await saveRememberedLoginEmail(email);
        await saveRememberedLoginName(name);
      } catch (e, st) {
        debugPrint(
          '[CareSignal][SignUp] save remembered login failed (account still created): $e',
        );
        debugPrint('$st');
      }
      if (!mounted) return;
      await navigateAfterAuth(context);
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '[CareSignal][SignUp] FirebaseAuthException '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      if (!mounted) return;
      showFirebaseAuthExceptionSnackBar(context, e, isSignUp: true);
    } catch (e, st) {
      debugPrint('[CareSignal][SignUp] unexpected error: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'I am signing up as a…',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _AccountTypeCard(
              title: 'Caregiver / family',
              subtitle: 'Daily check-ins, family support, and resources',
              icon: Icons.family_restroom_rounded,
              selected: _accountType == AccountType.caregiver,
              onTap: _loading
                  ? null
                  : () => setState(() => _accountType = AccountType.caregiver),
            ),
            const SizedBox(height: 10),
            _AccountTypeCard(
              title: 'Volunteer',
              subtitle:
                  'Help families with rides, respite, meals — and optionally host peer groups',
              icon: Icons.volunteer_activism_rounded,
              selected: _accountType == AccountType.volunteer,
              onTap: _loading
                  ? null
                  : () => setState(() => _accountType = AccountType.volunteer),
            ),
            const SizedBox(height: 10),
            _AccountTypeCard(
              title: 'Care partner',
              subtitle: 'View de-identified wellness trends shared by families',
              icon: Icons.handshake_rounded,
              selected: _accountType == AccountType.partner,
              onTap: _loading
                  ? null
                  : () => setState(() => _accountType = AccountType.partner),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signUp(),
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _signUp,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? const Color(0xFF439A7D) : Colors.black26;
    return Material(
      color: selected
          ? const Color(0xFF439A7D).withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? const Color(0xFF439A7D) : Colors.black45),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? const Color(0xFF439A7D) : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
