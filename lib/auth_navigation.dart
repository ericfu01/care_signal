import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'family_models.dart';
import 'family_onboarding_page.dart';
import 'family_repository.dart';
import 'home_page.dart';
import 'partner_home_page.dart';
import 'staff_home_page.dart';
import 'volunteer_background_check_page.dart';
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

  if (kDebugMode) {
    debugPrint(
      '[CareSignal][Auth] uid=${user.uid} accountType=${profile?.accountType} '
      'familyId=${profile?.familyId}',
    );
  }

  // Staff/partner take priority over family membership and volunteer lanes.
  if (profile?.isStaff == true) {
    return const StaffHomePage();
  }
  if (profile?.isPartner == true) {
    return const PartnerHomePage();
  }
  if (profile?.isVolunteer == true) {
    if (profile!.backgroundCheckBlocksVolunteer) {
      return const VolunteerBackgroundCheckPage();
    }
    return profile.volunteerProfileComplete
        ? const VolunteerHomePage()
        : const VolunteerSetupPage();
  }
  if (profile?.hasFamily == true) {
    return const HomePage();
  }
  return FamilyOnboardingPage(initialDisplayName: displayName);
}

/// After sign-up / profile changes, return to the root [AuthGate] route.
///
/// Do not push a fixed home page — that freezes routing and ignores later
/// Firestore `accountType` updates (e.g. promoting a user to staff).
Future<void> navigateAfterAuth(BuildContext context) async {
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}
