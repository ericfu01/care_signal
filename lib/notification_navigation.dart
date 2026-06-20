import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_repository.dart';
import 'family_volunteer_request_detail_page.dart';
import 'family_volunteer_requests_page.dart';
import 'volunteer_home_page.dart';
import 'volunteer_repository.dart';
import 'volunteer_request_detail_page.dart';

/// Routes notification taps to the relevant in-app screen.
class NotificationNavigation {
  NotificationNavigation._();

  static bool isVolunteerRequestType(String type) =>
      type == 'volunteer_request_cancelled' ||
      type == 'volunteer_request_new';

  static bool isFamilyVolunteerRequestType(String type) =>
      type == 'family_request_accepted' ||
      type == 'family_request_counter' ||
      type == 'family_request_completed' ||
      type == 'family_request_declined';

  static Future<void> openVolunteerRequest(
    BuildContext context, {
    required String familyUserId,
    required String requestId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final profile = await FamilyRepository.instance.getUserProfile(uid);
    if (!context.mounted) return;

    final catalogId = profile?.volunteerCatalogId?.trim() ?? '';
    final rawName = profile?.displayName.trim() ?? '';
    final volunteerName = rawName.isNotEmpty ? rawName : 'Volunteer';

    if (catalogId.isEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const VolunteerHomePage(),
        ),
      );
      return;
    }

    try {
      final assignment = await VolunteerRepository.instance.fetchAssignment(
        familyUserId: familyUserId,
        requestId: requestId,
      );
      if (!context.mounted) return;
      if (assignment == null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const VolunteerHomePage(),
          ),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => VolunteerRequestDetailPage(
            assignment: assignment,
            volunteerName: volunteerName,
            volunteerCatalogId: catalogId,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const VolunteerHomePage(),
        ),
      );
    }
  }

  static Future<void> openFamilyVolunteerRequests(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const FamilyVolunteerRequestsPage(),
      ),
    );
  }

  static Future<void> openFamilyVolunteerRequest(
    BuildContext context, {
    required String requestId,
  }) async {
    if (requestId.isEmpty) {
      await openFamilyVolunteerRequests(context);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FamilyVolunteerRequestDetailPage(
          requestId: requestId,
        ),
      ),
    );
  }

  static Future<void> openFromPayload(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'] as String? ?? '';

    if (isVolunteerRequestType(type)) {
      final familyUserId = data['familyUserId'] as String? ?? '';
      final requestId = data['requestId'] as String? ?? '';
      if (familyUserId.isNotEmpty && requestId.isNotEmpty) {
        await openVolunteerRequest(
          context,
          familyUserId: familyUserId,
          requestId: requestId,
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const VolunteerHomePage(),
          ),
        );
      }
      return;
    }

    if (isFamilyVolunteerRequestType(type)) {
      final requestId = data['requestId'] as String? ?? '';
      await openFamilyVolunteerRequest(context, requestId: requestId);
    }
  }
}
