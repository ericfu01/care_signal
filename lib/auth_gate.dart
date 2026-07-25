import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_navigation.dart';
import 'family_models.dart';
import 'family_repository.dart';
import 'sign_in_page.dart';

/// Keeps users signed in and routes to the correct home after launch.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const SignInPage();
        }

        return _AuthenticatedShell(user: user);
      },
    );
  }
}

class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell({required this.user});

  final User user;

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: FamilyRepository.instance.watchUserProfile(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your profile.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        final home = homeWidgetForProfile(widget.user, profile);
        return KeyedSubtree(
          key: ValueKey(_routeKey(profile)),
          child: home,
        );
      },
    );
  }

  String _routeKey(UserProfile? profile) {
    if (profile?.isStaff == true) return 'staff_home';
    if (profile?.isPartner == true) return 'partner_home';
    if (profile?.isVolunteer == true) {
      if (profile!.backgroundCheckBlocksVolunteer) {
        return 'volunteer_background_check';
      }
      return profile.volunteerProfileComplete
          ? 'volunteer_home'
          : 'volunteer_setup';
    }
    if (profile?.hasFamily == true) return 'family_home';
    return 'onboarding';
  }
}
