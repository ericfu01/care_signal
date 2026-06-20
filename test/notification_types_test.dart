import 'package:care_signal/app_notification.dart';
import 'package:care_signal/notification_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _notification(String type) {
  return AppNotification(
    id: 'n1',
    type: type,
    title: 'Title',
    body: 'Body',
    read: false,
  );
}

void main() {
  group('AppNotification type helpers', () {
    test('family volunteer request updates', () {
      expect(_notification('family_request_accepted').isFamilyVolunteerRequestUpdate, isTrue);
      expect(_notification('family_request_counter').isFamilyVolunteerRequestUpdate, isTrue);
      expect(_notification('family_request_completed').isFamilyVolunteerRequestUpdate, isTrue);
      expect(_notification('family_request_declined').isFamilyVolunteerRequestUpdate, isTrue);
      expect(_notification('family_message').isFamilyVolunteerRequestUpdate, isFalse);
    });

    test('volunteer assignment notifications', () {
      expect(_notification('volunteer_request_new').isVolunteerRequestNew, isTrue);
      expect(_notification('volunteer_request_cancelled').isVolunteerRequestCancelled, isTrue);
      expect(_notification('family_risk_alert').isFamilyRiskAlert, isTrue);
    });
  });

  group('NotificationNavigation type helpers', () {
    test('volunteer request types', () {
      expect(NotificationNavigation.isVolunteerRequestType('volunteer_request_new'), isTrue);
      expect(NotificationNavigation.isVolunteerRequestType('volunteer_request_cancelled'), isTrue);
      expect(NotificationNavigation.isVolunteerRequestType('family_request_accepted'), isFalse);
    });

    test('family volunteer request types', () {
      expect(NotificationNavigation.isFamilyVolunteerRequestType('family_request_accepted'), isTrue);
      expect(NotificationNavigation.isFamilyVolunteerRequestType('family_request_declined'), isTrue);
      expect(NotificationNavigation.isFamilyVolunteerRequestType('volunteer_request_new'), isFalse);
    });
  });
}
