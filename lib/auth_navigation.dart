import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_models.dart';
import 'family_onboarding_page.dart';
import 'family_repository.dart';
import 'home_page.dart';
import 'volunteer_home_page.dart';
import 'volunteer_setup_page.dart';

/// Resolves the home screen for a signed-in user.
Future<Widget> homeWidgetForUser(User user) async {
  final profile = await FamilyRepository.instance.getUserProfile(user.uid);
  return homeWidgetForProfile(user, profile);
}

Widget homeWidgetForProfile(User user, UserProfile? profile) {
  final displayName = profile?.displayName ??
      user.displayName?.trim() ??
      'Member';

  if (profile?.isVolunteer == true) {
    return profile!.volunteerProfileComplete
        ? const VolunteerHomePage()
        : const VolunteerSetupPage();
  }
  if (profile?.hasFamily == true) {
    return const HomePage();
  }
  return FamilyOnboardingPage(initialDisplayName: displayName);
}

/// After sign-in or sign-up, route by account type and profile completeness.
Future<void> navigateAfterAuth(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || !context.mounted) return;

  final next = await homeWidgetForUser(user);
  if (!context.mounted) return;

  await Navigator.of(context).pushAndRemoveUntil<void>(
    MaterialPageRoute<void>(builder: (_) => next),
    (route) => false,
  );
}
